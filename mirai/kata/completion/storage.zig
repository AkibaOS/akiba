//! Growable Indexed Completion Storage

const std = @import("std");

const constants = @import("mirai").kata.constants.pool;
const fields = @import("mirai").kata.strings.fields;
const guard = @import("asm").interrupts.guard;
const labels = @import("mirai").kata.strings.pool;
const memory = @import("mirai").memory;
const messages = @import("mirai").kata.strings.messages;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").kata.types;

const Completion = types.completion.Completion;
const RecordStore = memory.types.pool.store.create(Completion);
const Tree = tree.types.index.Tree;

var records: RecordStore = .{};
var identities: Tree = .{};
var owners: Tree = .{};

pub fn hasCapacity() bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    return records.LastGeneration != std.math.maxInt(u64) and records.Count != std.math.maxInt(usize);
}

pub fn find(id: u64) ?*Completion {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (id == constants.KERNEL_ID) return null;
    const node = tree.lookup.find(&identities, id) orelse return null;
    return @fieldParentPtr(fields.COMPLETION_INDEX, node);
}

pub fn reserve(id: u64, owner_id: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (id == constants.KERNEL_ID or id == owner_id or find(id) != null) return false;
    const record = records.reserveNamed(labels.COMPLETION) catch return false;
    record.* = .{ .ID = id, .OwnerID = owner_id };
    if (!tree.insert.insert(&identities, &record.Index, id)) {
        discard(record);
        return false;
    }
    if (!tree.insert.insert(&owners, &record.OwnerIndex, ownerKey(owner_id, id))) {
        if (!tree.remove.remove(&identities, &record.Index)) @panic(messages.INVALID_OBSERVER);
        discard(record);
        return false;
    }
    return true;
}

pub fn ownerOf(id: u64) ?u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = find(id) orelse return null;
    return record.OwnerID;
}

pub fn adopt(previous_owner: u64, new_owner: u64) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (previous_owner == new_owner) return;
    var current = tree.lookup.lowerBound(&owners, ownerKey(previous_owner, constants.KERNEL_ID));
    while (current) |node| {
        const record: *Completion = @fieldParentPtr(fields.COMPLETION_OWNER, node);
        if (record.OwnerID != previous_owner) break;
        current = tree.lookup.next(node);
        if (record.ID == new_owner) continue;
        if (!tree.remove.remove(&owners, node)) @panic(messages.INVALID_OBSERVER);
        record.OwnerID = new_owner;
        if (!tree.insert.insert(&owners, node, ownerKey(new_owner, record.ID))) @panic(messages.INVALID_OBSERVER);
    }
}

pub fn remove(record: *Completion) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record)) return false;
    if (record.Pending or record.Observers != 0 or record.Waiters.Count != 0 or (record.Published and !record.Collected)) return false;
    if (find(record.ID) != record or tree.lookup.find(&owners, ownerKey(record.OwnerID, record.ID)) != &record.OwnerIndex) return false;
    if (!tree.remove.remove(&identities, &record.Index) or !tree.remove.remove(&owners, &record.OwnerIndex)) @panic(messages.INVALID_OBSERVER);
    discard(record);
    return true;
}

fn ownerKey(owner_id: u64, id: u64) u128 {
    return (@as(u128, owner_id) << @bitSizeOf(u64)) | id;
}

fn discard(record: *Completion) void {
    if (!records.release(record)) @panic(messages.INVALID_OBSERVER);
    _ = records.collectAt(record);
    records.pruneEmpty();
}
