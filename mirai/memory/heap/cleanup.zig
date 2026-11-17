//! Kernel Heap Transaction Reclamation

const frames = @import("mirai").memory.heap.frames;
const kagami = @import("mirai").kagami;
const labels = @import("mirai").memory.strings.heap.storage;
const pmm = @import("mirai").pmm;
const state = @import("mirai").memory.heap.state;
const types = @import("mirai").memory.types.heap;

const Allocation = types.allocation.Allocation;

pub fn discard(record: *Allocation) void {
    state.remove(record);
    while (record.Frames) |frame| {
        const physical = frame.PA;
        if (frame.Mapped) {
            const removed = kagami.remove.remove(kagami.state.getKernelKagami(), frame.VA) orelse @panic(labels.INVALID_STATE);
            if (removed != physical) @panic(labels.INVALID_STATE);
        }
        frames.discard(frame);
        if (physical != 0) pmm.free.single.freePage(physical);
    }
    state.releaseExtent(record);
    state.discard(record);
}
