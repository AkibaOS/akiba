//! Nonreturning Persona Mode Lifecycle Services

const kata = @import("mirai").kata;
const thread = @import("mirai").thread;
const types = @import("shared").persona.types.invocation;

const InterruptFrame = @import("mirai").interrupts.types.frame.InterruptFrame;

pub fn dispatch(frame: *const InterruptFrame) void {
    switch (frame.RAX) {
        @intFromEnum(types.Service.FinishThread) => thread.finish.complete(),
        @intFromEnum(types.Service.Exit) => kata.finish.complete(frame.RDI),
        else => {},
    }
}
