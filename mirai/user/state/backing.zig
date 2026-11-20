//! Physical User Backing Membership And References

const std = @import("std");

const checks = @import("mirai").user.state.checks;
const fields = @import("mirai").user.strings.fields;
const guard = @import("asm").interrupts.guard;
const labels = @import("mirai").user.strings.ledger;
const memory = @import("mirai").memory;
const tree = @import("common").datatypes.tree;

const Backing = @import("mirai").user.types.backing.Backing;
const BackingStore = memory.types.pool.store.create(Backing);
const Tree = tree.types.index.Tree;
const UserError = @import("mirai").user.errors.memory.mappings.UserError;

var records: BackingStore = .{};
var physicals: Tree = .{};

pub fn find(physical_address: u64) ?*Backing {
    const flags = guard.acquire();
    defer guard.release(flags);
    const node = tree.lookup.find(&physicals, physical_address) orelse return null;
    return @fieldParentPtr(fields.PHYSICAL_INDEX, node);
}

pub fn owns(candidate: *const Backing) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    return records.owns(candidate) and candidate.References != 0 and find(candidate.PA) == candidate;
}

pub fn reserve(physical_address: u64) UserError!*Backing {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!checks.isPayloadPhysical(physical_address)) return UserError.InvalidPhysmap;
    if (find(physical_address) != null) return UserError.AlreadyOwned;
    const record = try records.reserveNamed(labels.BACKING);
    record.* = .{ .PA = physical_address };
    if (!tree.insert.insert(&physicals, &record.PhysicalIndex, physical_address)) {
        discard(record);
        return UserError.AlreadyOwned;
    }
    return record;
}

pub fn retainSealed(record: *Backing) UserError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!owns(record)) return UserError.InvalidOwnedMapping;
    if (record.Stage != .ReadOnly and record.Stage != .Executable) return UserError.NotShareable;
    if (record.References == std.math.maxInt(usize)) return UserError.OutOfMemory;
    record.References += 1;
}

pub fn detach(record: *Backing) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!owns(record)) @panic(labels.INVALID_STATE);
    record.References -= 1;
    if (record.References != 0) return;
    if (!tree.remove.remove(&physicals, &record.PhysicalIndex)) @panic(labels.INVALID_STATE);
    discard(record);
}

fn discard(record: *Backing) void {
    if (!records.release(record)) @panic(labels.INVALID_STATE);
    _ = records.collectAt(record);
    records.pruneEmpty();
}
