//! Collapse Banner

const serial = @import("../../drivers/serial/serial.zig");
const messages = @import("strings/strings.zig").messages;

pub fn render() void {
    serial.printf("\n", .{});
    serial.printf(messages.separator, .{});
    serial.printf(messages.collapse_header, .{});
    serial.printf(messages.separator, .{});
    serial.printf("\n", .{});
}

pub fn render_message(message: []const u8) void {
    serial.printf(messages.reason, .{message});
    serial.printf("\n", .{});
}

pub fn render_halt() void {
    serial.printf("\n", .{});
    serial.printf(messages.separator, .{});
    serial.printf(messages.system_halted, .{});
    serial.printf(messages.separator, .{});
}
