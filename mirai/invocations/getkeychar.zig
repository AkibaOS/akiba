//! Getkeychar invocation - read one character from keyboard

const handler = @import("handler.zig");
const keyboard = @import("../drivers/keyboard.zig");

pub fn invoke(context: *handler.InvocationContext) void {
    if (keyboard.read_char()) |char| {
        context.rax = char;
    } else {
        context.rax = @as(u64, @bitCast(@as(i64, -2)));
    }
}
