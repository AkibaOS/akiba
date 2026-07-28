//! Boot Message Printing

const serial = @import("mirai").drivers.serial;
const splash = @import("mirai").boot.splash;
const strings = @import("mirai").boot.strings;

const banner = strings.sequence.banner;
const messages = strings.sequence.messages;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    serial.write.printf(fmt, args);
}

pub fn phase(message: []const u8) void {
    serial.write.printf(messages.LINE, .{message});
    splash.report(message);
}

pub fn fail(message: []const u8) void {
    serial.write.printf(messages.LINE, .{message});
    splash.fail(message);
}

pub fn printBanner() void {
    serial.write.printf(banner.BLANK, .{});
    serial.write.printf(banner.TOP, .{});
    serial.write.printf(banner.TITLE, .{});
    serial.write.printf(banner.BOTTOM, .{});
    serial.write.printf(banner.BLANK, .{});
}
