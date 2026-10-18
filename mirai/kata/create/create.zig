//! Owned Kata Construction

const common = @import("common");
const errors = @import("mirai").kata.errors.ownership;
const kagami = @import("mirai").kagami;
const state = @import("mirai").kata.state;
const synchronize = @import("mirai").kagami.synchronize;
const types = @import("mirai").kata.types;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Kata = types.kata.Kata;
const OwnershipError = errors.OwnershipError;

pub fn create() (AllocationError || OwnershipError)!*Kata {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    if (state.getKernel() == null) return AllocationError.NotInitialized;
    if (!state.canReserve()) return AllocationError.OutOfMemory;
    const root = try kagami.create.create();
    errdefer kagami.destroy.destroy(root);
    if (!kagami.retain.acquire(root)) return OwnershipError.InvalidState;
    errdefer _ = kagami.retain.release(root);
    return state.reserve(root) orelse AllocationError.OutOfMemory;
}
