//! Inactive Kata Resource Destruction

const errors = @import("mirai").kata.errors.ownership;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const release = @import("mirai").user.memory.release;
const state = @import("mirai").kata.state;
const types = @import("mirai").kata.types;
const usererrors = @import("mirai").user.errors.memory;

const Kata = types.kata.Kata;
const OwnershipError = errors.OwnershipError;
const UserError = usererrors.UserError;

pub fn destroy(owner: *Kata) (OwnershipError || UserError)!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.owns(owner)) return OwnershipError.InvalidKata;
    if (owner.Permanent or owner.ThreadCount != 0) return OwnershipError.InUse;
    const root = owner.AddressSpace;
    if (root == kagami.state.getCurrentKagami() or kagami.activate.isActive(root) or
        root.ExecutionOwners != 1 or root.ReferenceCount != 1) return OwnershipError.InUse;
    try release.releaseAll(owner);
    if (!kagami.retain.release(root)) return OwnershipError.InvalidState;
    kagami.destroy.destroy(root);
    if (root.PML4Physical != 0) {
        _ = kagami.retain.acquire(root);
        return OwnershipError.InvalidState;
    }
    if (!state.release(owner)) return OwnershipError.InvalidState;
}
