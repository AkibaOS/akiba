//! Boot Messages

const serial = @import("../../../drivers/serial/serial.zig");
const banner = @import("../../strings/sequence/sequence.zig").banner;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    serial.printf(fmt, args);
}

pub fn print_banner() void {
    serial.printf(banner.BLANK, .{});
    serial.printf(banner.TOP, .{});
    serial.printf(banner.TITLE, .{});
    serial.printf(banner.BOTTOM, .{});
    serial.printf(banner.BLANK, .{});
}
