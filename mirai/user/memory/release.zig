//! Inactive Owned User Page Release

const checks = @import("mirai").user.state.checks;
const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const ledger = @import("mirai").user.state.ledger;
const limits = @import("mirai").user.constants.limits;
const pmm = @import("mirai").pmm;
const types = @import("mirai").user.types;
const usererrors = @import("mirai").user.errors.memory;

const sizes = common.constants.memory.sizes;
const Kata = kata.types.kata.Kata;
const Record = types.record.Record;
const UserError = usererrors.UserError;

pub fn releaseAll(owner: *Kata) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!checks.isValidOwner(owner)) return UserError.InvalidOwner;
    const root = owner.AddressSpace;
    if (owner.ThreadCount != 0 or root.ReferenceCount != 1 or
        root == kagami.state.getCurrentKagami() or kagami.activate.isActive(root)) return UserError.OwnerInUse;
    var index: usize = 0;
    while (index < limits.MAX_OWNED_PAGES) : (index += 1) {
        const record = ledger.at(index) orelse continue;
        if (record.Owner == owner) try validateRelease(record);
    }
    index = 0;
    while (index < limits.MAX_OWNED_PAGES) : (index += 1) {
        const record = ledger.at(index) orelse continue;
        if (record.Owner == owner) try releaseRecord(record);
    }
}

fn validateRelease(record: *const Record) UserError!void {
    const resolved = checks.lookupOwned(record) orelse return UserError.InvalidOwnedMapping;
    if ((record.Stage == .Loading and resolved.Executable) or
        (record.Stage == .Sealed and resolved.Writable)) return UserError.InvalidOwnedMapping;
    const alias = checks.lookupAlias(record) orelse return UserError.InvalidPhysmap;
    const loading = record.Stage == .Loading;
    if (alias.Writable != loading or alias.Entry.Writable != loading) return UserError.InvalidPhysmap;
    if (!loading and alias.PageSize != sizes.PAGE_SIZE) return UserError.InvalidPhysmap;
}

fn releaseRecord(record: *Record) UserError!void {
    const alias = checks.lookupAlias(record) orelse return UserError.InvalidPhysmap;
    const removed = kagami.remove.removeOwned(record.Owner.AddressSpace, record.VA, record.PA) orelse return UserError.InvalidOwnedMapping;
    if (removed != record.PA) return UserError.InvalidOwnedMapping;
    if (!alias.Writable) {
        const leaf: *kagami.types.entry.Entry = @constCast(alias.Entry);
        leaf.Writable = true;
        cpu.control.flushAllTLB();
    }
    pmm.free.single.freePage(record.PA);
    ledger.unregister(record);
}
