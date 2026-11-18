//! Kernel Heap Payload Frame Records

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const labels = @import("mirai").memory.strings.heap.storage;
const pmm = @import("mirai").pmm;
const pool = @import("mirai").memory.types.pool.store;
const tree = common.datatypes.tree;
const types = @import("mirai").memory.types.heap;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Allocation = types.allocation.Allocation;
const Frame = types.frame.Frame;
const FrameStore = pool.create(Frame);
const Tree = tree.types.index.Tree;

var records: FrameStore = .{};
var physicals: Tree = .{};

pub fn initialize() AllocationError!void {
    try records.init(labels.FRAMES);
}

pub fn reserve(owner: *Allocation, address: u64) AllocationError!*Frame {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (owner.FrameCount == std.math.maxInt(usize)) return AllocationError.RegionExhausted;
    const record = try records.reserve();
    record.* = .{ .Owner = owner, .VA = address, .Next = owner.Frames };
    owner.Frames = record;
    owner.FrameCount += 1;
    return record;
}

pub fn bind(record: *Frame, physical: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record)) return false;
    if (record.PA != 0 or record.PhysicalIndex.Linked or !pmm.state.isAllocated(physical)) return false;
    if (!tree.insert.insert(&physicals, &record.PhysicalIndex, physical)) return false;
    record.PA = physical;
    return true;
}

pub fn owns(record: *const Frame) bool {
    return records.owns(record);
}

pub fn find(physical: u64) ?*Frame {
    const flags = guard.acquire();
    defer guard.release(flags);
    const node = tree.lookup.find(&physicals, physical) orelse return null;
    return @fieldParentPtr(labels.PHYSICAL, node);
}

pub fn discard(record: *Frame) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record) or record.Owner.Frames != record or record.Owner.FrameCount == 0)
        @panic(labels.INVALID_STATE);
    if (record.PA != 0) {
        if (find(record.PA) != record or !tree.remove.remove(&physicals, &record.PhysicalIndex)) @panic(labels.INVALID_STATE);
    } else if (record.PhysicalIndex.Linked) @panic(labels.INVALID_STATE);
    record.Owner.Frames = record.Next;
    record.Owner.FrameCount -= 1;
    if (!records.release(record)) @panic(labels.INVALID_STATE);
    _ = records.collectAt(record);
}
