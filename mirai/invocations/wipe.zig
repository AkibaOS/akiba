//! Wipe invocation - Clear the terminal screen

const handler = @import("handler.zig");
const terminal = @import("../terminal.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    terminal.clear_screen();
    ctx.rax = 0;
}
