//! VGA text mode driver for basic text output

const VGA_BUFFER: *volatile [25 * 80]u16 = @ptrFromInt(0xB8000);
const VGA_WIDTH: usize = 80;

var row: usize = 0;
var col: usize = 0;

pub fn clear() void {
    var i: usize = 0;
    while (i < 25 * 80) : (i += 1) {
        VGA_BUFFER[i] = 0x0F00;
    }
    row = 0;
    col = 0;
}

pub fn put_char(c: u8) void {
    if (c == '\n') {
        row += 1;
        col = 0;
        return;
    }

    if (row >= 25) row = 0;
    if (col >= VGA_WIDTH) {
        col = 0;
        row += 1;
    }

    const index = row * VGA_WIDTH + col;
    VGA_BUFFER[index] = @as(u16, 0x0F00) | c;
    col += 1;
}

pub fn print(str: []const u8) void {
    for (str) |c| {
        put_char(c);
    }
}
