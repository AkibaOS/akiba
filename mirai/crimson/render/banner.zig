//! Collapse Banner

const serial = @import("../../drivers/serial/serial.zig");

pub fn render() void {
    serial.printf("\n", .{});
    serial.printf("================================================================================\n", .{});
    serial.printf("                              AKIBA HAS COLLAPSED                              \n", .{});
    serial.printf("================================================================================\n", .{});
    serial.printf("\n", .{});
}

pub fn render_message(message: []const u8) void {
    serial.printf("Reason: %s\n", .{message});
    serial.printf("\n", .{});
}

pub fn render_halt() void {
    serial.printf("\n", .{});
    serial.printf("================================================================================\n", .{});
    serial.printf("System halted. Please restart your computer.\n", .{});
    serial.printf("================================================================================\n", .{});
}
