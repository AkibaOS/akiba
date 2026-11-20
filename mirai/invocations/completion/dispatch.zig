//! Safe Persona Kata Completion Operations

const std = @import("std");

const abi = @import("mirai").invocations.types.abi;
const arguments = @import("mirai").invocations.errors.arguments;
const codec = @import("mirai").invocations.completion.codec;
const copy = @import("mirai").user.copy.transfer;
const errors = @import("mirai").kata.errors.completion.collection;
const kata = @import("mirai").kata;

const InterruptFrame = @import("mirai").interrupts.types.frame.InterruptFrame;
const Outcome = kata.types.outcome.Outcome;
const Record = @import("mirai").invocations.types.completion.record.Record;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn dispatch(current: *Thread, frame: *InterruptFrame, service: u64) void {
    if (frame.RDX < @sizeOf(Record)) {
        frame.RAX = @intFromEnum(abi.Status.BufferTooSmall);
        frame.RDX = @sizeOf(Record);
        return;
    }
    handle(current, frame, service) catch |failure| {
        frame.RAX = @intFromEnum(status(failure));
        frame.RDX = 0;
        return;
    };
    frame.RAX = @intFromEnum(abi.Status.Success);
    frame.RDX = @sizeOf(Record);
}

fn handle(current: *Thread, frame: *const InterruptFrame, service: u64) !void {
    if (!copy.validate(current.Owner, frame.RSI, @sizeOf(Record), true)) return arguments.ArgumentError.InvalidAddress;
    if (service == @intFromEnum(abi.Service.WaitCompletion)) {
        const outcome = try kata.wait.waitFromInvocation(frame.RDI);
        defer kata.wait.releaseFromInvocation(frame.RDI);
        try deliver(current, frame.RSI, outcome);
        return;
    }
    if (service != @intFromEnum(abi.Service.ObserveCompletion) and
        service != @intFromEnum(abi.Service.CollectCompletion)) return error.Unsupported;
    const record = try kata.completion.lifetime.borrow(frame.RDI);
    defer kata.completion.lifetime.drop(frame.RDI);
    const collect = service == @intFromEnum(abi.Service.CollectCompletion);
    if (collect and record.OwnerID != current.Owner.ID) return errors.CompletionError.NotOwner;
    const outcome = kata.completion.lifetime.observed(frame.RDI) orelse return errors.CompletionError.NotReady;
    try deliver(current, frame.RSI, outcome);
    if (collect) _ = try kata.completion.lifetime.collect(frame.RDI);
}

fn deliver(current: *Thread, address: u64, outcome: Outcome) !void {
    const record = codec.encode(outcome);
    try copy.write(current.Owner, address, std.mem.asBytes(&record));
}

fn status(failure: anyerror) abi.Status {
    return switch (failure) {
        error.NotInitialized => .NotInitialized,
        error.InvalidCaller, error.UnsafeContext, error.InvalidOwner => .InvalidCaller,
        error.InvalidTarget => .InvalidTarget,
        error.NotOwner => .NotOwner,
        error.NotReady => .WouldBlock,
        error.ObserverCapacity => .NoResources,
        error.InvalidAddress, error.InvalidUserRange, error.NotOwned, error.InvalidOwnedMapping, error.InvalidPhysmap, error.PermissionDenied, error.SealedPage => .InvalidAddress,
        error.Unsupported => .Unsupported,
        else => .InvalidState,
    };
}
