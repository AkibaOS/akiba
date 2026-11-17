//! Checked Allocation Free Kernel Heap Release

const bits = @import("utils").bits;
const cleanup = @import("mirai").memory.heap.cleanup;
const common = @import("common");
const frames = @import("mirai").memory.heap.frames;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const pmm = @import("mirai").pmm;
const state = @import("mirai").memory.heap.state;
const types = @import("mirai").memory.types.heap;

const sizes = common.constants.memory.sizes;
const Allocation = types.allocation.Allocation;

pub fn free(pointer: *anyopaque, size: usize) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const address = @intFromPtr(pointer);
    const record = state.find(address) orelse return false;
    if (size == 0 or record.RequestedSize != size or !state.ownsExtent(record) or record.Extent.Base != address or
        !validate(record)) return false;
    cleanup.discard(record);
    return true;
}

fn validate(record: *const Allocation) bool {
    const extent = record.Extent;
    if ((extent.Base & sizes.PAGE_MASK) != 0 or (extent.Size & sizes.PAGE_MASK) != 0 or
        extent.Size == 0 or record.RequestedSize > extent.Size or record.FrameCount != extent.Size / sizes.PAGE_SIZE) return false;
    var remaining = record.FrameCount;
    var current = record.Frames;
    while (current) |frame| {
        if (remaining == 0 or !frames.owns(frame)) return false;
        remaining -= 1;
        if (frame.Owner != record or frame.VA != extent.Base + remaining * sizes.PAGE_SIZE or !frame.Mapped or
            frame.PA == 0 or (frame.PA & sizes.PAGE_MASK) != 0 or frames.find(frame.PA) != frame or
            frame.PA / sizes.PAGE_SIZE >= pmm.state.getState().TotalPages or
            !bits.operations.testBit(pmm.state.getState().Bitmap, frame.PA / sizes.PAGE_SIZE)) return false;
        const mapped = kagami.extract.lookup(kagami.state.getKernelKagami(), frame.VA) orelse return false;
        if (mapped.PageSize != sizes.PAGE_SIZE or mapped.PhysicalAddress != frame.PA or !mapped.Writable or
            mapped.UserAccessible or mapped.Executable or
            (mapped.Entry.AvailableLow & kagami.constants.ownership.WIRED) == 0) return false;
        current = frame.Next;
    }
    return remaining == 0;
}
