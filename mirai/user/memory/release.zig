//! Inactive Owned User Page Release

const access = @import("mirai").user.state.access;
const backing = @import("mirai").user.state.backing;
const checks = @import("mirai").user.state.checks;
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const ledger = @import("mirai").user.state.ledger;
const pmm = @import("mirai").pmm;
const types = @import("mirai").user.types;
const usererrors = @import("mirai").user.errors.memory;

const Backing = types.backing.Backing;
const Kata = kata.types.kata.Kata;
const Lookup = kagami.types.lookup.Lookup;
const Record = types.record.Record;
const UserError = usererrors.UserError;

pub fn releaseAll(owner: *Kata) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!checks.isValidOwner(owner)) return UserError.InvalidOwner;
    const root = owner.AddressSpace orelse return UserError.InvalidOwner;
    if (owner.ThreadCount != 0 or root.ReferenceCount != 1 or
        root == kagami.state.getCurrentKagami() or kagami.activate.isActive(root)) return UserError.OwnerInUse;
    var current = ledger.first(owner);
    while (current) |record| : (current = ledger.next(record)) try validateRelease(record);
    current = ledger.first(owner);
    while (current) |record| {
        current = ledger.next(record);
        try releaseRecord(record);
    }
}

fn validateRelease(record: *const Record) UserError!void {
    try access.validate(record, false);
}

fn releaseRecord(record: *Record) UserError!void {
    const alias = checks.lookupAlias(record) orelse return UserError.InvalidPhysmap;
    const frame = record.Backing;
    const physical = frame.PA;
    const removed = kagami.remove.removeOwned(record.Owner.AddressSpace.?, record.VA, physical) orelse return UserError.InvalidOwnedMapping;
    if (removed != physical) return UserError.InvalidOwnedMapping;
    const last = restoreLastAlias(frame, alias);
    ledger.unregister(record);
    if (last) pmm.free.single.freePage(physical);
}

pub fn dropSealed(frame: *Backing) UserError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const alias = try access.sealedAlias(frame);
    const physical = frame.PA;
    const last = restoreLastAlias(frame, alias);
    backing.detach(frame);
    if (last) pmm.free.single.freePage(physical);
}

fn restoreLastAlias(frame: *const Backing, alias: Lookup) bool {
    if (frame.References != 1) return false;
    if (!alias.Writable) {
        const leaf: *kagami.types.entry.Entry = @constCast(alias.Entry);
        leaf.Writable = true;
        cpu.control.flushAllTLB();
    }
    return true;
}
