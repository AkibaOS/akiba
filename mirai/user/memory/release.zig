//! Inactive Owned User Page Release

const access = @import("mirai").user.state.access;
const checks = @import("mirai").user.state.checks;
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const ledger = @import("mirai").user.state.ledger;
const limits = @import("mirai").user.constants.limits;
const pmm = @import("mirai").pmm;
const types = @import("mirai").user.types;
const usererrors = @import("mirai").user.errors.memory;

const Kata = kata.types.kata.Kata;
const Record = types.record.Record;
const UserError = usererrors.UserError;

pub fn releaseAll(owner: *Kata) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!checks.isValidOwner(owner)) return UserError.InvalidOwner;
    const root = owner.AddressSpace orelse return UserError.InvalidOwner;
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
    try access.validate(record, false);
}

fn releaseRecord(record: *Record) UserError!void {
    const alias = checks.lookupAlias(record) orelse return UserError.InvalidPhysmap;
    const removed = kagami.remove.removeOwned(record.Owner.AddressSpace.?, record.VA, record.PA) orelse return UserError.InvalidOwnedMapping;
    if (removed != record.PA) return UserError.InvalidOwnedMapping;
    if (!alias.Writable) {
        const leaf: *kagami.types.entry.Entry = @constCast(alias.Entry);
        leaf.Writable = true;
        cpu.control.flushAllTLB();
    }
    pmm.free.single.freePage(record.PA);
    ledger.unregister(record);
}
