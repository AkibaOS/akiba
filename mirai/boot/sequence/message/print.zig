//! Boot Messages

const serial = @import("../../../drivers/serial/serial.zig");
const banner = @import("../strings/strings.zig").banner;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    serial.printf(fmt, args);
}

pub fn print_banner() void {
    serial.printf(banner.blank, .{});
    serial.printf(banner.top, .{});
    serial.printf(banner.title, .{});
    serial.printf(banner.bottom, .{});
    serial.printf(banner.blank, .{});
}
