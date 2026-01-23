//! Getkeychar invocation - read one character from keyboard

const keyboard = @import("../drivers/keyboard.zig");
const handler = @import("handler.zig");
const serial = @import("../drivers/serial.zig");

pub fn invoke(context: *handler.InvocationContext) void {
    if (keyboard.read_char()) |char| {
        context.rax = char;
    } else {
        // No input available - return -2 (EAGAIN)
        context.rax = @as(u64, @bitCast(@as(i64, -2)));
    }
}
