//! Collapse Banner

const serial = @import("../../drivers/serial/serial.zig");
const messages = @import("../strings/strings.zig").messages;

pub fn render() void {
    serial.printf("\n", .{});
    serial.printf(messages.SEPARATOR, .{});
    serial.printf(messages.COLLAPSE_HEADER, .{});
    serial.printf(messages.SEPARATOR, .{});
    serial.printf("\n", .{});
}

pub fn render_message(message: []const u8) void {
    serial.printf(messages.REASON, .{message});
    serial.printf("\n", .{});
}

pub fn render_halt() void {
    serial.printf("\n", .{});
    serial.printf(messages.SEPARATOR, .{});
    serial.printf(messages.SYSTEM_HALTED, .{});
    serial.printf(messages.SEPARATOR, .{});
}
