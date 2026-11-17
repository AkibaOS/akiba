//! Owned Kata Construction

const common = @import("common");
const errors = @import("mirai").kata.errors.ownership;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const state = @import("mirai").kata.state;
const thread = @import("mirai").thread;
const types = @import("mirai").kata.types;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Kata = types.kata.Kata;
const OwnershipError = errors.OwnershipError;

pub fn create() (AllocationError || OwnershipError)!*Kata {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const current = thread.state.getCurrent() orelse return AllocationError.NotInitialized;
    if (!thread.state.owns(current) or current.Status != .Running) return OwnershipError.InvalidState;
    return createFor(current.Owner);
}

pub fn createFor(launcher: *const Kata) (AllocationError || OwnershipError)!*Kata {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (state.getKernel() == null) return AllocationError.NotInitialized;
    if (!state.owns(launcher)) return OwnershipError.InvalidKata;
    if (launcher.State != .Alive and launcher.State != .Sleeping) return OwnershipError.InvalidState;
    if (!state.canReserve()) return AllocationError.OutOfMemory;
    const root = try kagami.create.create();
    errdefer _ = kagami.destroy.destroy(root);
    if (!kagami.retain.acquire(root)) return OwnershipError.InvalidState;
    errdefer _ = kagami.retain.release(root);
    return state.reserve(root, launcher.ID) orelse AllocationError.OutOfMemory;
}
