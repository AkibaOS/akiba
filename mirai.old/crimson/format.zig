//! Crimson formatting utilities

pub fn u32_decimal(value: u32, buffer: []u8) usize {
    if (buffer.len == 0) return 0;

    var temp: [10]u8 = undefined;
    var temp_pos: usize = 0;
    var val = value;

    if (val == 0) {
        buffer[0] = '0';
        return 1;
    }

    while (val > 0 and temp_pos < 10) {
        temp[temp_pos] = @as(u8, @truncate(val % 10)) + '0';
        val /= 10;
        temp_pos += 1;
    }

    var pos: usize = 0;
    while (temp_pos > 0 and pos < buffer.len) {
        temp_pos -= 1;
        buffer[pos] = temp[temp_pos];
        pos += 1;
    }

    return pos;
}

pub fn u64_hex(value: u64, buffer: []u8) usize {
    const hex = "0123456789ABCDEF";
    var shift: u6 = 60;
    var pos: usize = 0;

    while (pos < 16 and pos < buffer.len) : (pos += 1) {
        const nibble = @as(u8, @truncate((value >> shift) & 0xF));
        buffer[pos] = hex[nibble];
        if (shift >= 4) {
            shift -= 4;
        }
    }

    return pos;
}

pub fn register(label: []const u8, value: u64, buffer: []u8) []const u8 {
    var pos: usize = 0;

    for (label) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    if (pos < buffer.len) {
        buffer[pos] = ':';
        pos += 1;
    }
    if (pos < buffer.len) {
        buffer[pos] = ' ';
        pos += 1;
    }

    pos += u64_hex(value, buffer[pos..]);

    return buffer[0..pos];
}

pub fn stack_frame(num: usize, addr: u64, buffer: []u8) []const u8 {
    var pos: usize = 0;

    if (pos < buffer.len) {
        buffer[pos] = '#';
        pos += 1;
    }

    pos += u32_decimal(@truncate(num), buffer[pos..]);

    if (pos < buffer.len) {
        buffer[pos] = ' ';
        pos += 1;
    }

    pos += u64_hex(addr, buffer[pos..]);

    return buffer[0..pos];
}

pub fn assert_message(condition: []const u8, file: []const u8, line: u32, buffer: []u8) []const u8 {
    var pos: usize = 0;

    const prefix = "Assertion failed: ";
    for (prefix) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    for (condition) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    const at_str = " at ";
    for (at_str) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    for (file) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    if (pos < buffer.len) {
        buffer[pos] = ':';
        pos += 1;
    }

    pos += u32_decimal(line, buffer[pos..]);

    return buffer[0..pos];
}
