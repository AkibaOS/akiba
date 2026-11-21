//! Forward The Private First Weaver Request To Its Boot Owner

const std = @import("std");

const abi = @import("shared").persona.types.invocation;
const handoff = @import("mirai").bootstrap.weaver.handoff;

const Frame = @import("mirai").interrupts.types.frame.InterruptFrame;
const Operation = @import("shared").pulse.types.boot.control.Operation;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn dispatch(caller: *Thread, frame: *Frame) void {
    const value = perform(caller, frame) catch |failure| {
        frame.RAX = @intFromEnum(switch (failure) {
            error.InvalidArgument => abi.Status.InvalidArgument,
            error.InvalidCaller, error.InvalidThread => abi.Status.InvalidCaller,
            error.NotInitialized => abi.Status.NotInitialized,
            error.OutOfMemory => abi.Status.NoResources,
            else => abi.Status.InvalidState,
        });
        frame.RDX = 0;
        return;
    };
    frame.RAX = @intFromEnum(abi.Status.Success);
    frame.RDX = value;
}

fn perform(caller: *Thread, frame: *const Frame) !u64 {
    const operation = std.enums.fromInt(Operation, frame.RDI) orelse return error.InvalidArgument;
    if (frame.RDX != 0 or frame.R10 != 0) return error.InvalidArgument;
    return switch (operation) {
        .Start => if (frame.RSI == 0) handoff.start(caller) else error.InvalidArgument,
        .Grow => if (frame.RSI == 0) handoff.grow(caller) else error.InvalidArgument,
        .Confirm => confirmed: {
            try handoff.confirm(caller, frame.RSI);
            break :confirmed 0;
        },
    };
}
