//! Kernel Stack Ownership And Cache State

const std = @import("std");

const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const labels = @import("mirai").memory.strings.stack.storage;
const limits = @import("mirai").memory.constants.stack.limits;
const pool = @import("mirai").memory.types.pool.store;
const range = @import("mirai").memory.range;
const tree = common.datatypes.tree;
const types = @import("mirai").memory.types;

const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.allocation.AllocationError;
const Record = types.stack.record.Record;
const RecordStore = pool.create(Record);
const Region = types.range.region.Region;
const Tree = tree.types.index.Tree;

var global_state: types.stack.state.State = .{};
var records: RecordStore = .{};
var region: Region = .{};
var addresses: Tree = .{};
var initialized: bool = false;

pub fn getState() *types.stack.state.State {
    return &global_state;
}

pub fn canCommitBoot() bool {
    return global_state.FreeList == null and global_state.FreeCount == 0 and global_state.TotalCount == 0 and
        global_state.BootStackBase == 0 and !initialized;
}

pub fn commitBoot(base: u64, top: u64) bool {
    const expected_base = limits.AREA_BASE + limits.GUARD_PAGES * sizes.PAGE_SIZE;
    if (!canCommitBoot() or base != expected_base or top != base + limits.STACK_SIZE) return false;
    global_state.BootStackBase = base;
    global_state.BootStackTop = top;
    global_state.TotalCount = 1;
    global_state.HighWatermark = 1;
    return true;
}

pub fn initialize() AllocationError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (initialized) return;
    if (!kagami.state.hasOwnedKernel() or global_state.BootStackBase == 0) return AllocationError.NotInitialized;
    if (limits.MAX_SLOTS <= 1) return AllocationError.InvalidSize;
    try range.lifecycle.initialize(&region, limits.AREA_BASE + limits.SLOT_SIZE, (limits.MAX_SLOTS - 1) * limits.SLOT_SIZE, labels.REGION);
    errdefer if (!range.lifecycle.deinitialize(&region)) @panic(labels.INVALID_STATE);
    try records.init(labels.RECORDS);
    initialized = true;
}

pub fn find(base: u64) ?*Record {
    const flags = guard.acquire();
    defer guard.release(flags);
    const node = tree.lookup.find(&addresses, base) orelse return null;
    const record: *Record = @fieldParentPtr(labels.INDEX, node);
    return if (records.owns(record)) record else null;
}

pub fn owns(record: *const Record) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record)) return false;
    return find(record.Stack.Base) == record and range.storage.owns(&region, record.Extent) and !record.Extent.Free;
}

pub fn reserve() AllocationError!*Record {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!initialized) return AllocationError.NotInitialized;
    if (global_state.TotalCount == std.math.maxInt(u64)) return AllocationError.RegionExhausted;
    const record = try records.reserve();
    errdefer releaseRecord(record);
    const extent = try range.reserve.reserve(&region, limits.SLOT_SIZE, sizes.PAGE_SIZE);
    const base = extent.Base + limits.GUARD_PAGES * sizes.PAGE_SIZE;
    record.* = .{ .Extent = extent, .Stack = .{ .Base = base, .Top = base + limits.STACK_SIZE } };
    return record;
}

pub fn publish(record: *Record) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record) or record.Phase != .Reserved or record.PageCount != limits.STACK_PAGES or
        global_state.TotalCount == std.math.maxInt(u64)) return false;
    if (!tree.insert.insert(&addresses, &record.Index, record.Stack.Base)) return false;
    record.Phase = .Live;
    global_state.TotalCount += 1;
    global_state.HighWatermark = @max(global_state.HighWatermark, global_state.TotalCount);
    return true;
}

pub fn takeCached() ?*Record {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = global_state.FreeList orelse return null;
    if (!records.owns(record) or record.Phase != .Cached or global_state.FreeCount == 0 or
        find(record.Stack.Base) != record) @panic(labels.INVALID_STATE);
    if (isPinned(record.Stack.Base)) return null;
    global_state.FreeList = record.Next;
    global_state.FreeCount -= 1;
    record.Next = null;
    record.Phase = .Live;
    return record;
}

pub fn cache(record: *Record) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record) or record.Phase != .Live or record.Next != null or isPinned(record.Stack.Base) or
        find(record.Stack.Base) != record or global_state.FreeCount == std.math.maxInt(u64)) return false;
    record.Next = global_state.FreeList;
    record.Phase = .Cached;
    global_state.FreeList = record;
    global_state.FreeCount += 1;
    return true;
}

pub fn discard(record: *Record) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record) or record.Phase == .Cached or record.Pinned or record.PageCount != 0 or record.Next != null)
        @panic(labels.INVALID_STATE);
    if (record.Index.Linked) {
        if (find(record.Stack.Base) != record or global_state.TotalCount <= 1 or !tree.remove.remove(&addresses, &record.Index))
            @panic(labels.INVALID_STATE);
        global_state.TotalCount -= 1;
    }
    if (!range.release.release(&region, record.Extent)) @panic(labels.INVALID_STATE);
    releaseRecord(record);
}

pub fn retain(base: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = find(base) orelse return false;
    if (record.Phase != .Live or record.Pinned) return false;
    record.Pinned = true;
    return true;
}

pub fn release(base: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = find(base) orelse return false;
    if (record.Phase != .Live or !record.Pinned or isLive(base)) return false;
    record.Pinned = false;
    return true;
}

pub fn isPinned(base: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (find(base)) |record| {
        if (record.Pinned) return true;
    }
    return isLive(base);
}

pub fn isAllocatedBase(base: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (global_state.BootStackBase != 0 and base == global_state.BootStackBase) return true;
    const record = find(base) orelse return false;
    return record.Phase == .Live;
}

fn isLive(base: u64) bool {
    if (base == global_state.BootStackBase) return true;
    const pointer = cpu.state.readStackPointer();
    return base <= pointer and pointer - base < limits.STACK_SIZE;
}

fn releaseRecord(record: *Record) void {
    if (!records.release(record)) @panic(labels.INVALID_STATE);
    _ = records.collectAt(record);
}
