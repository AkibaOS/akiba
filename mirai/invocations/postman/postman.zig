//! Copied Postman Invocation Services

const std = @import("std");

const abi = @import("mirai").invocations.types.abi;
const arguments = @import("mirai").invocations.errors.arguments;
const copy = @import("mirai").user.copy.transfer;
const limits = @import("mirai").user.constants.limits;
const messages = @import("mirai").thread.strings.shift.messages;
const postman = @import("mirai").postman;
const sensei = @import("mirai").sensei;
const types = @import("mirai").invocations.types.postman;

const ArgumentError = arguments.ArgumentError;
const Header = postman.types.letter.Header;
const InterruptFrame = @import("mirai").interrupts.handlers.common.InterruptFrame;
const Result = types.Result;
const Thread = @import("mirai").thread.types.thread.Thread;
const View = postman.types.letter.View;

pub fn dispatch(current: *Thread, frame: *InterruptFrame, service: u64) void {
    const result = handle(current, frame, service) catch |failure| {
        frame.RAX = @intFromEnum(status(failure));
        frame.RDX = 0;
        return;
    };
    frame.RAX = @intFromEnum(result.Status);
    frame.RDX = result.Value;
}

fn handle(current: *Thread, frame: *const InterruptFrame, service: u64) !Result {
    return switch (service) {
        @intFromEnum(abi.Service.Send) => send(current, frame),
        @intFromEnum(abi.Service.Receive) => receive(current, frame),
        @intFromEnum(abi.Service.Call) => call(current, frame),
        @intFromEnum(abi.Service.Reply) => reply(current, frame),
        @intFromEnum(abi.Service.CollectReply) => collect(current, frame),
        @intFromEnum(abi.Service.Close) => close(current),
        else => Result{ .Status = .Unsupported },
    };
}

fn readPayload(current: *Thread, address: u64, length: u64, buffer: []u8) ![]const u8 {
    if (length > buffer.len) return ArgumentError.TooLarge;
    const count: usize = @intCast(length);
    if (count != 0) try copy.read(current.Owner, buffer[0..count], address);
    return buffer[0..count];
}

fn validateOutput(current: *Thread, buffer: u64, length: usize, metadata: u64) ArgumentError!void {
    if ((length != 0 and !copy.validate(current.Owner, buffer, length, true)) or
        !copy.validate(current.Owner, metadata, @sizeOf(Header), true)) return ArgumentError.InvalidAddress;
    if (length != 0 and buffer < metadata + @sizeOf(Header) and metadata < buffer + length)
        return ArgumentError.InvalidAddress;
}

fn deliver(current: *Thread, buffer: u64, capacity: u64, metadata: u64, view: View) !Result {
    if (view.Header.Length != view.Payload.len or view.Payload.len > limits.MAX_COPY_BYTES) @panic(messages.INVALID_CONTEXT);
    if (capacity < view.Payload.len) return .{ .Status = .BufferTooSmall, .Value = view.Payload.len };
    try validateOutput(current, buffer, view.Payload.len, metadata);
    if (view.Payload.len != 0) try copy.write(current.Owner, buffer, view.Payload);
    try copy.write(current.Owner, metadata, std.mem.asBytes(&view.Header));
    return .{ .Value = view.Payload.len };
}

fn send(current: *Thread, frame: *const InterruptFrame) !Result {
    var bytes: [limits.MAX_COPY_BYTES]u8 = undefined;
    const contents = try readPayload(current, frame.RSI, frame.RDX, &bytes);
    try postman.delivery.send(current, frame.RDI, frame.R10, contents);
    return .{};
}

fn receive(current: *Thread, frame: *const InterruptFrame) !Result {
    try validateOutput(current, frame.RDI, @intCast(@min(frame.RSI, limits.MAX_COPY_BYTES)), frame.RDX);
    const waiters = try postman.receive.queue(current);
    try sensei.wait.blockFromInvocation(waiters, postman.receive.ready, @ptrCast(current), null);
    errdefer _ = sensei.wait.wakeOldest(waiters) catch @panic(messages.INVALID_CONTEXT);
    const view = try postman.receive.peek(current);
    const result = try deliver(current, frame.RDI, frame.RSI, frame.RDX, view);
    if (result.Status == .Success) {
        try postman.receive.consume(current);
    } else {
        _ = try sensei.wait.wakeOldest(waiters);
    }
    return result;
}

fn call(current: *Thread, frame: *const InterruptFrame) !Result {
    var descriptor: types.Call = undefined;
    try copy.read(current.Owner, std.mem.asBytes(&descriptor), frame.RDI);
    try validateOutput(current, descriptor.Reply, @intCast(@min(descriptor.ReplyCapacity, limits.MAX_COPY_BYTES)), descriptor.Metadata);
    var bytes: [limits.MAX_COPY_BYTES]u8 = undefined;
    const contents = try readPayload(current, descriptor.Request, descriptor.RequestLength, &bytes);
    const preferred = try postman.call.begin(current, descriptor.Destination, descriptor.Type, contents);
    const waiters = try postman.call.queue(current);
    try sensei.wait.blockFromInvocation(waiters, postman.call.ready, @ptrCast(current), preferred);
    const view = try postman.call.peek(current);
    const result = try deliver(current, descriptor.Reply, descriptor.ReplyCapacity, descriptor.Metadata, view);
    if (result.Status == .Success) try postman.call.consume(current);
    return result;
}

fn reply(current: *Thread, frame: *const InterruptFrame) !Result {
    var bytes: [limits.MAX_COPY_BYTES]u8 = undefined;
    const contents = try readPayload(current, frame.RSI, frame.RDX, &bytes);
    try postman.reply.send(current, frame.RDI, frame.R10, contents);
    return .{};
}

fn collect(current: *Thread, frame: *const InterruptFrame) !Result {
    const view = try postman.call.peek(current);
    const result = try deliver(current, frame.RDI, frame.RSI, frame.RDX, view);
    if (result.Status == .Success) try postman.call.consume(current);
    return result;
}

fn close(current: *Thread) !Result {
    try postman.mailbox.close(current.Owner);
    return .{};
}

fn status(failure: anyerror) abi.Status {
    return switch (failure) {
        error.NotInitialized => .NotInitialized,
        error.InvalidThread, error.UnsafeContext => .InvalidCaller,
        error.CopyTooLarge, error.TooLarge => .TooLarge,
        error.Full => .Full,
        error.NoResources, error.OutOfMemory, error.CapacityReached, error.OwnershipCapacity => .NoResources,
        error.InvalidPeer => .InvalidPeer,
        error.Closed => .Closed,
        error.Busy, error.AlreadyManaged => .Busy,
        error.InvalidReply => .InvalidReply,
        error.PeerGone => .PeerGone,
        error.WouldBlock => .WouldBlock,
        error.InvalidAddress, error.InvalidUserRange, error.NotOwned, error.InvalidOwnedMapping, error.InvalidPhysmap, error.SealedPage, error.PermissionDenied => .InvalidAddress,
        else => .InvalidState,
    };
}
