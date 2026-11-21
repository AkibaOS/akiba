//! Queue Actual IRQ Bytes For The Bound Keyboard Driver

const guard = @import("asm").interrupts.guard;
const instances = @import("mirai").device.instance.registry;
const postman = @import("mirai").postman;
const sensei = @import("mirai").sensei;

const Result = @import("shared").persona.types.result.Result;
const Status = @import("shared").persona.types.invocation.Status;
const Stream = @import("mirai").device.types.keyboard.stream.Stream;
const Thread = @import("mirai").thread.types.thread.Thread;

var stream: Stream = .{};
var device: ?u64 = null;

pub fn attach(identifier: u64) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    device = identifier;
}

pub fn push(byte: u8) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const identifier = device orelse return;
    const owner = instances.assignedOwner(identifier) orelse return;
    select(owner.ID);
    if (stream.Count == stream.Bytes.len) {
        stream.Lost = true;
        stream.Head = 0;
        stream.Count = 0;
    }
    stream.Bytes[(stream.Head + stream.Count) % stream.Bytes.len] = byte;
    stream.Count += 1;
    if (postman.inbox.find(owner)) |mailbox| {
        if (mailbox.Receivers.Count != 0) postman.notification.receivers(mailbox);
    }
}

pub fn check(caller: *Thread, handle: u64) !void {
    try postman.validate.current(caller);
    const target = instances.resolve(caller.Owner, handle) orelse return error.InvalidCaller;
    if (target.Kind != .Keyboard or target.ID != device) return error.InvalidTarget;
}

pub fn next(caller: *Thread, handle: u64) !Result {
    const flags = guard.acquire();
    defer guard.release(flags);
    try check(caller, handle);
    select(caller.Owner.ID);
    const waiters = try postman.receive.queue(caller);
    try sensei.wait.blockFromInvocation(waiters, ready, @ptrCast(caller), null);
    if (stream.Lost) {
        stream.Lost = false;
        return .{ .Status = @intFromEnum(Status.InputLost), .Value = 0 };
    }
    if (stream.Count == 0) return .{ .Status = @intFromEnum(Status.WouldBlock), .Value = 0 };
    const byte = stream.Bytes[stream.Head];
    stream.Head = (stream.Head + 1) % stream.Bytes.len;
    stream.Count -= 1;
    return .{ .Status = @intFromEnum(Status.Success), .Value = byte };
}

fn ready(context: ?*anyopaque) bool {
    return stream.Lost or stream.Count != 0 or postman.receive.ready(context);
}

fn select(identifier: u64) void {
    if (stream.Driver != identifier) stream = .{ .Driver = identifier };
}
