//! Akiba parameter parsing

pub const Value = union(enum) {
    scalar: []const u8,
    list: []const []const u8,
};

pub const Named = struct {
    key: []const u8,
    value: Value,
};

pub const Params = struct {
    positionals: []const Value,
    named: []const Named,

    pub fn positional(self: Params, index: usize) ?Value {
        if (index >= self.positionals.len) return null;
        return self.positionals[index];
    }

    pub fn get(self: Params, key: []const u8) ?Value {
        for (self.named) |n| {
            if (eql(n.key, key)) return n.value;
        }
        return null;
    }

    pub fn getString(self: Params, key: []const u8) ?[]const u8 {
        const val = self.get(key) orelse return null;
        return switch (val) {
            .scalar => |s| s,
            .list => null,
        };
    }

    pub fn getList(self: Params, key: []const u8) ?[]const []const u8 {
        const val = self.get(key) orelse return null;
        return switch (val) {
            .scalar => null,
            .list => |l| l,
        };
    }

    pub fn getBool(self: Params, key: []const u8) ?bool {
        const val = self.getString(key) orelse return null;
        if (eql(val, "true")) return true;
        if (eql(val, "false")) return false;
        return null;
    }

    pub fn getInt(self: Params, key: []const u8) ?i64 {
        const val = self.getString(key) orelse return null;
        return parseInt(val);
    }
};

pub const Error = error{
    EmptyToken,
    EmptyKey,
    EmptyValue,
    InvalidKey,
    DuplicateKey,
    PositionalAfterNamed,
    LeadingComma,
    TrailingComma,
};

const MAX_POSITIONALS = 16;
const MAX_NAMED = 32;
const MAX_LIST_ITEMS = 16;

var positional_storage: [MAX_POSITIONALS]Value = undefined;
var named_storage: [MAX_NAMED]Named = undefined;
var list_storage: [MAX_POSITIONALS + MAX_NAMED][MAX_LIST_ITEMS][]const u8 = undefined;
var list_index: usize = 0;

pub fn parse(pc: u32, pv: [*]const [*:0]const u8) Error!Params {
    var positional_count: usize = 0;
    var named_count: usize = 0;
    var in_named = false;
    list_index = 0;

    // Skip program name (pv[0])
    var i: u32 = 1;
    while (i < pc) : (i += 1) {
        const arg = sliceFromCstr(pv[i]);

        if (arg.len == 0) return Error.EmptyToken;

        const eq_pos = indexOf(arg, '=');

        if (eq_pos) |pos| {
            // Named parameter
            in_named = true;

            if (pos == 0) return Error.EmptyKey;
            if (pos == arg.len - 1) return Error.EmptyValue;

            const key = arg[0..pos];
            const value_str = arg[pos + 1 ..];

            if (!isValidKey(key)) return Error.InvalidKey;
            if (hasDuplicateKey(named_storage[0..named_count], key)) return Error.DuplicateKey;

            const value = try parseValue(value_str);
            named_storage[named_count] = .{ .key = key, .value = value };
            named_count += 1;
        } else {
            // Positional
            if (in_named) return Error.PositionalAfterNamed;

            const value = try parseValue(arg);
            positional_storage[positional_count] = value;
            positional_count += 1;
        }
    }

    return Params{
        .positionals = positional_storage[0..positional_count],
        .named = named_storage[0..named_count],
    };
}

fn parseValue(str: []const u8) Error!Value {
    if (str.len == 0) return Error.EmptyValue;
    if (str[0] == ',') return Error.LeadingComma;
    if (str[str.len - 1] == ',') return Error.TrailingComma;

    // Check for commas
    var comma_count: usize = 0;
    for (str) |c| {
        if (c == ',') comma_count += 1;
    }

    if (comma_count == 0) {
        return Value{ .scalar = str };
    }

    // Parse list
    var items: [][]const u8 = list_storage[list_index][0..];
    var item_count: usize = 0;
    var start: usize = 0;

    for (str, 0..) |c, j| {
        if (c == ',') {
            if (j == start) return Error.LeadingComma; // Empty segment
            items[item_count] = str[start..j];
            item_count += 1;
            start = j + 1;
        }
    }

    // Last item
    if (start == str.len) return Error.TrailingComma;
    items[item_count] = str[start..];
    item_count += 1;

    list_index += 1;

    return Value{ .list = items[0..item_count] };
}

fn isValidKey(key: []const u8) bool {
    if (key.len == 0) return false;

    const first = key[0];
    if (!isLetter(first)) return false;

    for (key[1..]) |c| {
        if (!isLetter(c) and !isDigit(c) and c != '_') return false;
    }

    return true;
}

fn isLetter(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn hasDuplicateKey(named: []const Named, key: []const u8) bool {
    for (named) |n| {
        if (eql(n.key, key)) return true;
    }
    return false;
}

fn indexOf(str: []const u8, char: u8) ?usize {
    for (str, 0..) |c, i| {
        if (c == char) return i;
    }
    return null;
}

fn eql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ac, bc| {
        if (ac != bc) return false;
    }
    return true;
}

fn sliceFromCstr(cstr: [*:0]const u8) []const u8 {
    var len: usize = 0;
    while (cstr[len] != 0) : (len += 1) {}
    return cstr[0..len];
}

fn parseInt(str: []const u8) ?i64 {
    if (str.len == 0) return null;

    var negative = false;
    var start: usize = 0;

    if (str[0] == '-') {
        negative = true;
        start = 1;
    }

    if (start >= str.len) return null;

    var result: i64 = 0;
    for (str[start..]) |c| {
        if (!isDigit(c)) return null;
        result = result * 10 + @as(i64, c - '0');
    }

    return if (negative) -result else result;
}
