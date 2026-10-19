//! Bounded Owned User Page Ledger

const checks = @import("mirai").user.state.checks;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const limits = @import("mirai").user.constants.limits;
const types = @import("mirai").user.types;
const usererrors = @import("mirai").user.errors.memory;

const sizes = common.constants.memory.sizes;
const Kata = kata.types.kata.Kata;
const Record = types.record.Record;
const UserError = usererrors.UserError;

var records: [limits.MAX_OWNED_PAGES]Record = undefined;
var occupied: [limits.MAX_OWNED_PAGES]bool = [_]bool{false} ** limits.MAX_OWNED_PAGES;

pub fn at(index: usize) ?*Record {
    if (index >= records.len or !occupied[index]) return null;
    return &records[index];
}

pub fn find(owner: *const Kata, virtual_address: u64) ?*Record {
    for (&records, occupied) |*record, used| {
        if (used and record.Owner == owner and record.VA == virtual_address) return record;
    }
    return null;
}

pub fn ownsPhysical(physical_address: u64) bool {
    for (&records, occupied) |*record, used| {
        if (used and record.PA == physical_address) return true;
    }
    return false;
}

pub fn hasCapacity() bool {
    for (occupied) |used| {
        if (!used) return true;
    }
    return false;
}

pub fn register(owner: *Kata, virtual_address: u64, physical_address: u64) UserError!*Record {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!checks.isValidOwner(owner)) return UserError.InvalidOwner;
    if ((virtual_address & sizes.PAGE_MASK) != 0) return UserError.AddressNotAligned;
    if (!checks.isValidRange(virtual_address, sizes.PAGE_SIZE)) return UserError.InvalidUserRange;
    if (!checks.isPayloadPhysical(physical_address)) return UserError.InvalidPhysmap;
    if (find(owner, virtual_address) != null or ownsPhysical(physical_address)) return UserError.AlreadyOwned;
    for (&occupied, 0..) |*used, index| {
        if (used.*) continue;
        records[index] = .{ .Owner = owner, .VA = virtual_address, .PA = physical_address };
        used.* = true;
        return &records[index];
    }
    return UserError.OwnershipCapacity;
}

pub fn unregister(record: *Record) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    for (&records, 0..) |*candidate, index| {
        if (candidate != record) continue;
        occupied[index] = false;
        candidate.* = undefined;
        return;
    }
}
