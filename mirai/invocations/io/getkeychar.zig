//! Getkeychar invocation - View one character from keyboard

const handler = @import("../handler.zig");
const keyboard = @import("../../drivers/keyboard/keyboard.zig");
const result = @import("../../utils/types/result.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    if (keyboard.read_char()) |char| {
        result.set_value(ctx, char);
    } else {
        result.set_no_data(ctx);
    }
}
