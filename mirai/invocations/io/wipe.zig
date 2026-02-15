//! Wipe invocation - Clear the terminal screen

const handler = @import("../handler.zig");
const result = @import("../../utils/types/result.zig");
const terminal = @import("../../graphics/terminal/terminal.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    terminal.clear_screen();
    result.set_ok(ctx);
}
