//! Dispatch The Private Keyboard Byte Stream Operation

const std = @import("std");

const stream = @import("mirai").device.keyboard.stream;

const Frame = @import("mirai").interrupts.types.frame.InterruptFrame;
const Operation = @import("shared").keyboard.types.operation.Operation;
const Result = @import("shared").persona.types.result.Result;
const Status = @import("shared").persona.types.invocation.Status;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn dispatch(caller: *Thread, frame: *Frame) void {
    const result = perform(caller, frame) catch |failure| Result{
        .Status = @intFromEnum(switch (@as(anyerror, failure)) {
            error.InvalidArgument => Status.InvalidArgument,
            error.InvalidCaller, error.InvalidThread, error.UnsafeContext => Status.InvalidCaller,
            error.Closed => Status.Closed,
            error.OutOfMemory, error.NoResources => Status.NoResources,
            else => Status.InvalidState,
        }),
        .Value = 0,
    };
    frame.RAX = result.Status;
    frame.RDX = result.Value;
}

fn perform(caller: *Thread, frame: *const Frame) !Result {
    try stream.check(caller);
    if (frame.RSI != 0 or frame.RDX != 0 or frame.R10 != 0) return error.InvalidArgument;
    switch (std.enums.fromInt(Operation, frame.RDI) orelse return error.InvalidArgument) {
        .Check => return .{ .Status = @intFromEnum(Status.Success), .Value = 0 },
        .Next => return stream.next(caller),
    }
}
