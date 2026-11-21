//! Stop Only A Published Kata Owned By The Calling Launcher

const kata = @import("mirai").kata;
const postman = @import("mirai").postman;

const Frame = @import("mirai").interrupts.types.frame.InterruptFrame;
const Status = @import("shared").persona.types.invocation.Status;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn dispatch(caller: *Thread, frame: *Frame) void {
    stop(caller, frame) catch |failure| {
        frame.RAX = @intFromEnum(switch (failure) {
            error.InvalidThread => Status.InvalidCaller,
            error.NotInitialized => Status.NotInitialized,
            error.InvalidArgument => Status.InvalidArgument,
            error.NotOwner => Status.NotOwner,
            error.InvalidTarget, error.InvalidKata => Status.InvalidTarget,
            else => Status.InvalidState,
        });
        frame.RDX = 0;
        return;
    };
    frame.RAX = @intFromEnum(Status.Success);
    frame.RDX = 0;
}

fn stop(caller: *Thread, frame: *const Frame) !void {
    try postman.validate.current(caller);
    if (frame.RDX != 0 or frame.R10 != 0 or frame.RDI == caller.Owner.ID) return error.InvalidArgument;
    const owner = kata.completion.storage.ownerOf(frame.RDI) orelse return error.InvalidTarget;
    if (owner != caller.Owner.ID) return error.NotOwner;
    if (kata.completion.lifetime.peek(frame.RDI) != null) return;
    const target = kata.state.findByID(frame.RDI) orelse return error.InvalidTarget;
    if (target.State != .Alive and target.State != .Sleeping) return error.InvalidState;
    try kata.finish.terminate(target, .{ .Exited = frame.RSI });
}
