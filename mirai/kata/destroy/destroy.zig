//! Inactive Kata Resource Destruction

const errors = @import("mirai").kata.errors.ownership;
const kagami = @import("mirai").kagami;
const state = @import("mirai").kata.state;
const synchronize = @import("mirai").kagami.synchronize;
const types = @import("mirai").kata.types;

const Kata = types.kata.Kata;
const OwnershipError = errors.OwnershipError;

pub fn destroy(owner: *Kata) OwnershipError!void {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    if (!state.owns(owner)) return OwnershipError.InvalidKata;
    if (owner.Permanent or owner.ThreadCount != 0) return OwnershipError.InUse;
    const root = owner.AddressSpace;
    if (root == kagami.state.getCurrentKagami() or kagami.activate.isActive(root) or
        root.ExecutionOwners != 1 or root.ReferenceCount != 1) return OwnershipError.InUse;
    if (!kagami.retain.release(root)) return OwnershipError.InvalidState;
    kagami.destroy.destroy(root);
    if (root.PML4Physical != 0) {
        _ = kagami.retain.acquire(root);
        return OwnershipError.InvalidState;
    }
    if (!state.release(owner)) return OwnershipError.InvalidState;
}
