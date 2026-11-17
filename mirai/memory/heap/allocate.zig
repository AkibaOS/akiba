//! Virtually Contiguous Kernel Heap Allocation

const std = @import("std");

const cleanup = @import("mirai").memory.heap.cleanup;
const common = @import("common");
const errors = @import("mirai").memory.errors.allocation;
const frames = @import("mirai").memory.heap.frames;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const pmm = @import("mirai").pmm;
const state = @import("mirai").memory.heap.state;

const sizes = common.constants.memory.sizes;
const AllocationError = errors.AllocationError;

pub fn allocate(size: usize, alignment: usize) AllocationError!*anyopaque {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (size == 0 or size > std.math.maxInt(usize) - sizes.PAGE_MASK) return AllocationError.SizeTooLarge;
    if (alignment == 0 or (alignment & (alignment - 1)) != 0) return AllocationError.InvalidAlignment;
    const bytes = (size + sizes.PAGE_MASK) & ~sizes.PAGE_MASK;
    const search = pmm.state.getState().SearchStart;
    errdefer pmm.state.getState().SearchStart = search;
    const record = try state.reserve(size, @max(alignment, sizes.PAGE_SIZE), bytes);
    errdefer cleanup.discard(record);
    var offset: u64 = 0;
    while (offset < bytes) : (offset += sizes.PAGE_SIZE) {
        const address = record.Extent.Base + offset;
        const frame = try frames.reserve(record, address);
        const physical = try pmm.allocate.single.allocatePageZeroed();
        if (!frames.bind(frame, physical)) {
            pmm.free.single.freePage(physical);
            return AllocationError.InvalidSize;
        }
        try kagami.enter.enter(kagami.state.getKernelKagami(), address, physical, kagami.constants.protection.KERNEL_WRITE | kagami.constants.protection.WIRED);
        frame.Mapped = true;
    }
    if (!state.publish(record)) return AllocationError.AlreadyMapped;
    return @ptrFromInt(record.Extent.Base);
}
