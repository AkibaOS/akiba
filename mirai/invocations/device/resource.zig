//! Dispatch Typed Operations On An Assigned Device Resource

const std = @import("std");

const display = @import("mirai").invocations.device.display;
const instances = @import("mirai").device.instance.registry;
const postman = @import("mirai").postman;
const stream = @import("mirai").device.keyboard.stream;

const Frame = @import("mirai").interrupts.types.frame.InterruptFrame;
const Operation = @import("shared").device.types.operation.Operation;
const Result = @import("shared").persona.types.result.Result;
const Status = @import("shared").persona.types.invocation.Status;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn dispatch(caller: *Thread, frame: *Frame) void {
    const result = perform(caller, frame) catch |failure| Result{
        .Status = @intFromEnum(switch (@as(anyerror, failure)) {
            error.InvalidArgument => Status.InvalidArgument,
            error.InvalidCaller, error.InvalidThread, error.UnsafeContext => Status.InvalidCaller,
            error.InvalidTarget => Status.InvalidTarget,
            error.InvalidUserRange, error.InvalidAddress, error.NotOwned, error.InvalidOwnedMapping, error.InvalidPhysmap, error.SealedPage => Status.InvalidAddress,
            error.CopyTooLarge => Status.TooLarge,
            error.NotInitialized => Status.NotInitialized,
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
    try postman.validate.current(caller);
    if (frame.R10 != 0) return error.InvalidArgument;
    const operation = std.enums.fromInt(Operation, frame.RDI) orelse return error.InvalidArgument;
    if (operation == .SurfaceDescribe or operation == .SurfaceRow) {
        try display.perform(caller, operation, frame.RSI, frame.RDX);
        return .{ .Status = @intFromEnum(Status.Success), .Value = 0 };
    }
    if (frame.RDX != 0) return error.InvalidArgument;
    return switch (operation) {
        .Lease => if (frame.RSI != 0) error.InvalidArgument else .{
            .Status = @intFromEnum(Status.Success),
            .Value = instances.handleFor(caller.Owner) orelse return error.InvalidCaller,
        },
        .StreamProbe => probed: {
            try stream.check(caller, frame.RSI);
            break :probed .{ .Status = @intFromEnum(Status.Success), .Value = 0 };
        },
        .StreamNext => stream.next(caller, frame.RSI),
        .SurfaceDescribe, .SurfaceRow => unreachable,
    };
}
