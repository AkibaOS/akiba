//! VGA text mode driver

const ports = @import("../../common/constants/ports.zig");
const vga_const = @import("../../common/constants/vga.zig");
const vga_limits = @import("../../common/limits/vga.zig");

const buffer: *volatile [vga_limits.HEIGHT * vga_limits.WIDTH]u16 = @ptrFromInt(ports.VGA_BUFFER_ADDR);

var row: usize = 0;
var col: usize = 0;

pub fn clear() void {
    for (buffer) |*cell| {
        cell.* = vga_const.DEFAULT_ATTR;
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

    if (row >= vga_limits.HEIGHT) row = 0;
    if (col >= vga_limits.WIDTH) {
        col = 0;
        row += 1;
    }

    const index = row * vga_limits.WIDTH + col;
    buffer[index] = vga_const.DEFAULT_ATTR | c;
    col += 1;
}

pub fn print(str: []const u8) void {
    for (str) |c| {
        put_char(c);
    }
}
