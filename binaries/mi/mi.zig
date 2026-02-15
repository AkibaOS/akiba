//! mi - Stack viewer for Akiba OS

const colors = @import("colors");
const format = @import("format");
const io = @import("io");
const sys = @import("sys");

const PERM_OWNER: u8 = 1;
const PERM_WORLD: u8 = 2;
const PERM_READ_ONLY: u8 = 3;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    var target_path: []const u8 = "";

    if (pc > 1) {
        const arg = pv[1];
        var len: usize = 0;
        while (arg[len] != 0) : (len += 1) {}
        target_path = arg[0..len];
    }

    display_stack(target_path) catch |err| {
        format.color("mi: ", colors.white);
        format.color(@errorName(err), colors.red);
        format.print("\n");
        return 1;
    };

    return 0;
}

fn display_stack(path: []const u8) !void {
    var entries: [128]io.StackEntry = undefined;
    const count = io.viewstack(path, &entries) catch {
        format.color("mi: cannot access '", colors.red);
        format.print(path);
        format.colorln("': No such stack.", colors.red);
        return;
    };

    if (count == 0) {
        format.color(path, colors.cyan);
        format.colorln(" is empty.", colors.gray);
        return;
    }

    var max_access_len: usize = 6;
    var max_size_len: usize = 4;
    var max_owner_len: usize = 7;
    const max_date_len: usize = 19;

    for (0..count) |i| {
        const entry = &entries[i];
        const perms = get_permissions(entry.permission_type);
        if (perms.len > max_access_len) max_access_len = perms.len;

        var size_buf: [32]u8 = undefined;
        const size_str = format.formatSize(entry.size, &size_buf);
        if (size_str.len > max_size_len) max_size_len = size_str.len;

        if (entry.owner_name_len > max_owner_len) {
            max_owner_len = entry.owner_name_len;
        }
    }

    format.print("Access");
    print_padding(max_access_len - 6 + 2);
    format.print("Size");
    print_padding(max_size_len - 4 + 2);
    format.print("Persona");
    print_padding(max_owner_len - 7 + 3);
    format.print("Modified");
    print_padding(max_date_len - 8 + 1);
    format.println("Name");

    var stack_count: usize = 0;
    var unit_count: usize = 0;
    var total_size: u64 = 0;

    for (0..count) |i| {
        const entry = &entries[i];
        const identity = entry.identity[0..entry.identity_len];
        const owner = entry.owner_name[0..entry.owner_name_len];

        const perms = get_permissions(entry.permission_type);
        format.color(perms, colors.cyan);
        print_padding(max_access_len - perms.len + 2);

        var size_buf: [32]u8 = undefined;
        const size_str = format.formatSize(entry.size, &size_buf);
        format.color(size_str, colors.green);
        print_padding(max_size_len - size_str.len + 2);

        format.color(owner, colors.yellow);
        print_padding(max_owner_len - owner.len + 3);

        var date_buf: [32]u8 = undefined;
        const date_str = format.formatDate(entry.modified_time, &date_buf);
        format.color(date_str, colors.blue);
        print_padding(max_date_len - date_str.len + 2);

        if (entry.is_stack) {
            stack_count += 1;
            total_size += entry.size;
            format.color(identity, colors.cyan);
            format.color("/", colors.blue);
        } else {
            unit_count += 1;
            total_size += entry.size;
            format.print(identity);
        }
        format.print("\n");
    }

    format.print("\n");

    var buf: [16]u8 = undefined;
    format.color(format.intToStr(stack_count, &buf), colors.gray);
    format.color(" stacks  ", colors.gray);
    format.color(format.intToStr(unit_count, &buf), colors.gray);
    format.color(" units  ", colors.gray);
    var size_buf: [32]u8 = undefined;
    format.colorln(format.formatSize(total_size, &size_buf), colors.gray);
}

fn get_permissions(perm_type: u8) []const u8 {
    return switch (perm_type) {
        PERM_OWNER => "Owner",
        PERM_WORLD => "World",
        PERM_READ_ONLY => "Read Only",
        else => "Owner",
    };
}

fn print_padding(count: usize) void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        format.print(" ");
    }
}
