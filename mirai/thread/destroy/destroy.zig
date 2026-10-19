//! Inactive Thread Resource Destruction

const errors = @import("mirai").thread.errors.ownership;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const stack = @import("mirai").memory.stack;
const state = @import("mirai").thread.state;
const types = @import("mirai").thread.types;

const OwnershipError = errors.OwnershipError;
const Thread = types.thread.Thread;

pub fn destroy(thread: *Thread) OwnershipError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.owns(thread)) return OwnershipError.InvalidThread;
    if (thread.Permanent or thread.Managed or thread == state.getCurrent() or
        (thread.Status != .Ready and thread.Status != .Stopped)) return OwnershipError.InUse;
    const owner = thread.Owner;
    if (!kata.state.owns(owner) or owner.ThreadCount == 0) return OwnershipError.InvalidOwner;
    state.notifyInactive(thread);
    if (!stack.state.release(thread.Stack.Base)) return OwnershipError.InUse;
    stack.free.free(thread.Stack);
    owner.ThreadCount -= 1;
    if (!state.release(thread)) return OwnershipError.InvalidState;
}
