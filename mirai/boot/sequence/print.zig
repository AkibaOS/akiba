//! Boot Message Printing

const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").boot.strings;

const banner = strings.sequence.banner;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    serial.write.printf(fmt, args);
}

pub fn printBanner() void {
    serial.write.printf(banner.BLANK, .{});
    serial.write.printf(banner.TOP, .{});
    serial.write.printf(banner.TITLE, .{});
    serial.write.printf(banner.BOTTOM, .{});
    serial.write.printf(banner.BLANK, .{});
}
