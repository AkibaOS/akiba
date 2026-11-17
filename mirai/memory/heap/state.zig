//! Indexed Kernel Heap Allocation State

const common = @import("common");
const frames = @import("mirai").memory.heap.frames;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const labels = @import("mirai").memory.strings.heap.storage;
const pool = @import("mirai").memory.types.pool.store;
const range = @import("mirai").memory.range;
const tree = common.datatypes.tree;
const types = @import("mirai").memory.types;

const layout = common.constants.memory.layout;
const AllocationError = common.errors.memory.allocation.AllocationError;
const Allocation = types.heap.allocation.Allocation;
const AllocationStore = pool.create(Allocation);
const Region = types.range.region.Region;
const Tree = tree.types.index.Tree;

var region: Region = .{};
var records: AllocationStore = .{};
var addresses: Tree = .{};
var initialized: bool = false;

pub fn initialize() AllocationError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (initialized) return;
    if (!kagami.state.hasOwnedKernel()) return AllocationError.NotInitialized;
    if (layout.MMIO_BASE <= layout.KERNEL_HEAP) return AllocationError.InvalidSize;
    try range.lifecycle.initialize(&region, layout.KERNEL_HEAP, layout.MMIO_BASE - layout.KERNEL_HEAP, labels.REGION);
    errdefer if (!range.lifecycle.deinitialize(&region)) @panic(labels.INVALID_STATE);
    try records.init(labels.ALLOCATIONS);
    errdefer if (!records.deinit()) @panic(labels.INVALID_STATE);
    try frames.initialize();
    initialized = true;
}

pub fn reserve(size: usize, alignment: usize, bytes: u64) AllocationError!*Allocation {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!initialized) return AllocationError.NotInitialized;
    const record = try records.reserve();
    errdefer releaseRecord(record);
    const extent = try range.reserve.reserve(&region, bytes, alignment);
    record.* = .{ .Extent = extent, .RequestedSize = size, .Alignment = alignment };
    return record;
}

pub fn publish(record: *Allocation) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record)) return false;
    return tree.insert.insert(&addresses, &record.Index, record.Extent.Base);
}

pub fn find(address: u64) ?*Allocation {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!initialized) return null;
    const node = tree.lookup.find(&addresses, address) orelse return null;
    const record: *Allocation = @fieldParentPtr(labels.INDEX, node);
    return if (records.owns(record)) record else null;
}

pub fn belongs(address: u64) bool {
    return address >= layout.KERNEL_HEAP and address < layout.MMIO_BASE;
}

pub fn ownsExtent(record: *const Allocation) bool {
    return range.storage.owns(&region, record.Extent) and !record.Extent.Free and
        range.lookup.find(&region, record.Extent.Base) == record.Extent;
}

pub fn remove(record: *Allocation) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record)) @panic(labels.INVALID_STATE);
    if (record.Index.Linked and (find(record.Extent.Base) != record or !tree.remove.remove(&addresses, &record.Index)))
        @panic(labels.INVALID_STATE);
}

pub fn releaseExtent(record: *Allocation) void {
    if (!range.release.release(&region, record.Extent)) @panic(labels.INVALID_STATE);
}

pub fn discard(record: *Allocation) void {
    if (!records.owns(record) or record.Index.Linked or record.Frames != null or record.FrameCount != 0)
        @panic(labels.INVALID_STATE);
    releaseRecord(record);
}

fn releaseRecord(record: *Allocation) void {
    if (!records.release(record)) @panic(labels.INVALID_STATE);
    _ = records.collectAt(record);
}
