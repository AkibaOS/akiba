//! Collapse Banner

const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;

const messages = strings.messages;

pub fn render() void {
    serial.write.printf("\n", .{});
    serial.write.printf(messages.SEPARATOR, .{});
    serial.write.printf(messages.COLLAPSE_HEADER, .{});
    serial.write.printf(messages.SEPARATOR, .{});
    serial.write.printf("\n", .{});
}

pub fn renderMessage(message: []const u8) void {
    serial.write.printf(messages.REASON, .{message});
    serial.write.printf("\n", .{});
}

pub fn renderHalt() void {
    serial.write.printf("\n", .{});
    serial.write.printf(messages.SEPARATOR, .{});
    serial.write.printf(messages.SYSTEM_HALTED, .{});
    serial.write.printf(messages.SEPARATOR, .{});
}
