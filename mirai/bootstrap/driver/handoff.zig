//! Admit Only The Exact Shipped AHCI Driver For Initial Pulse

const authority = @import("mirai").device.ahci.authority;
const guard = @import("asm").interrupts.guard;
const image = @import("mirai").bootstrap.image;
const memory = @import("mirai").memory.allocator.native;
const postman = @import("mirai").postman;
const rollback = @import("mirai").bootstrap.strings.image.rollback;
const stack = @import("mirai").bootstrap.constants.driver.stack;
const storage = @import("mirai").bootstrap.storage.handoff;

const Image = @import("mirai").bootstrap.types.driver.image.Image;
const Kata = @import("mirai").kata.types.kata.Kata;
const Thread = @import("mirai").thread.types.thread.Thread;

var pending: ?Image = null;

pub fn arm(owner: *const Kata, bytes: []const u8) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (pending != null or owner.State != .Born or bytes.len == 0) return error.InvalidState;
    pending = .{ .PulseID = owner.ID, .Bytes = try memory.get().dupe(u8, bytes) };
}

pub fn disarm(owner: *const Kata) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const source = pending orelse return;
    if (source.PulseID != owner.ID or owner.State != .Born) return;
    pending = null;
    memory.get().free(source.Bytes);
}

pub fn startAhci(caller: *Thread) !u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    try postman.validate.current(caller);
    const disk = storage.forPulse(caller.Owner) orelse return error.InvalidCaller;
    const source = pending orelse return error.InvalidState;
    if (source.PulseID != caller.Owner.ID) return error.InvalidCaller;
    const prepared = try image.prepare.prepare(caller.Owner, source.Bytes, .{ .StackBase = stack.BASE, .StackPages = stack.PAGES });
    errdefer image.abort.abort(prepared) catch @panic(rollback.ROLLBACK_FAILED);
    try authority.grant(prepared.Owner, disk);
    errdefer authority.rollback(prepared.Owner);
    const identifier = try image.start.start(prepared);
    pending = null;
    memory.get().free(source.Bytes);
    return identifier;
}

pub fn confirmAhci(caller: *Thread, driver: u64) !void {
    try postman.validate.current(caller);
    if (storage.forPulse(caller.Owner) == null) return error.InvalidCaller;
    try authority.confirmDriver(caller.Owner.ID, driver);
}
