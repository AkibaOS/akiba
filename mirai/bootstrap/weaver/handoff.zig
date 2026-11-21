//! Restrict The First Weaver Launch To The Initial Pulse And Owned Bytes

const guard = @import("asm").interrupts.guard;
const image = @import("mirai").bootstrap.image;
const kata = @import("mirai").kata;
const labels = @import("mirai").bootstrap.strings.image.rollback;
const memory = @import("mirai").memory.allocator.native;
const postman = @import("mirai").postman;
const stack = @import("mirai").bootstrap.constants.weaver.stack;
const thread = @import("mirai").thread;

const HandoffError = @import("mirai").bootstrap.errors.weaver.handoff.HandoffError;
const Kata = kata.types.kata.Kata;
const State = @import("mirai").bootstrap.types.weaver.state.State;
const Thread = thread.types.thread.Thread;

var handoff: ?State = null;

pub fn arm(owner: *const Kata, bytes: []const u8) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (handoff != null or bytes.len == 0 or !kata.state.owns(owner) or owner.Permanent or owner.State != .Born)
        return HandoffError.InvalidState;
    handoff = .{ .PulseID = owner.ID, .Image = try memory.get().dupe(u8, bytes) };
}

pub fn disarm(identifier: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const state = handoff orelse return false;
    if (state.PulseID != identifier or state.WeaverID != null) return false;
    const bytes = state.Image orelse return false;
    handoff = null;
    memory.get().free(bytes);
    return true;
}

pub fn start(caller: *Thread) !u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    const state = try owned(caller);
    const bytes = state.Image orelse return HandoffError.InvalidState;
    const prepared = try image.prepare.prepare(caller.Owner, bytes, .{ .StackBase = stack.BASE, .StackPages = stack.PAGES });
    errdefer image.abort.abort(prepared) catch @panic(labels.ROLLBACK_FAILED);
    const identifier = try image.start.start(prepared);
    state.WeaverID = identifier;
    state.Image = null;
    memory.get().free(bytes);
    return identifier;
}

pub fn confirm(caller: *Thread, identifier: u64) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const state = try owned(caller);
    if (state.Confirmed or state.WeaverID != identifier or !started(identifier)) return HandoffError.InvalidState;
    state.Confirmed = true;
}

pub fn readyFor(identifier: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const state = handoff orelse return false;
    return state.PulseID == identifier and state.Confirmed and started(state.WeaverID orelse return false);
}

fn owned(caller: *Thread) !*State {
    try postman.validate.current(caller);
    const state = if (handoff) |*current| current else return HandoffError.InvalidCaller;
    if (state.PulseID != caller.Owner.ID) return HandoffError.InvalidCaller;
    return state;
}

fn started(identifier: u64) bool {
    const owner = kata.state.findByID(identifier) orelse return false;
    if (owner.State != .Alive and owner.State != .Sleeping) return false;
    const target = thread.state.firstFor(owner) orelse return false;
    return target.Mode == .Persona and target.Started;
}
