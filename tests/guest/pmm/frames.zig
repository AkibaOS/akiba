//! Scratch Physical Frame Regressions

const std = @import("std");

const address = @import("utils").address;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.memory.fixtures;
const labels = @import("tests").guest.strings.memory.witnesses;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const before = pmm.state.getStatistics();
    var frames: [inputs.FRAME_COUNT]u64 = undefined;
    var count: usize = 0;
    defer for (frames[0..count]) |frame| pmm.free.single.freePage(frame);
    while (count < frames.len) {
        const frame = try pmm.allocate.single.allocatePage();
        frames[count] = frame;
        count += 1;
        verify.require((frame & sizes.PAGE_MASK) == 0 and
            pmm.state.isAllocated(frame), labels.PMM_FRAMES);
        for (frames[0 .. count - 1]) |other| verify.require(frame != other, labels.PMM_FRAMES);
    }
    const allocated = pmm.state.getStatistics();
    verify.require(allocated.FreePages + frames.len == before.FreePages and
        allocated.UsedPages == before.UsedPages + frames.len and
        allocated.TotalPages == before.TotalPages and allocated.ReservedPages == before.ReservedPages and
        allocated.MetadataPages == before.MetadataPages and allocated.MetadataBytes == before.MetadataBytes and
        allocated.TotalPages == allocated.FreePages + allocated.UsedPages + allocated.ReservedPages and
        allocated.totalBytes() == before.totalBytes() and
        allocated.freeBytes() + frames.len * sizes.PAGE_SIZE == before.freeBytes() and
        allocated.usedBytes() == before.usedBytes() + frames.len * sizes.PAGE_SIZE, labels.PMM_COUNTS);
    count -= 1;
    const released = frames[count];
    const dirty: [*]u8 = @ptrFromInt(address.translate.physToVirt(released));
    @memset(dirty[0..sizes.PAGE_SIZE], inputs.DIRTY_BYTE);
    pmm.free.single.freePage(released);
    const reused = try pmm.allocate.single.allocatePageZeroed();
    frames[count] = reused;
    count += 1;
    verify.require(reused == released, labels.PMM_REUSE);
    const zeroed: [*]const u8 = @ptrFromInt(address.translate.physToVirt(reused));
    verify.require(std.mem.allEqual(u8, zeroed[0..sizes.PAGE_SIZE], 0), labels.PMM_ZERO);
    verify.require(std.meta.eql(pmm.state.getStatistics(), allocated), labels.PMM_COUNTS);
    for (frames) |frame| pmm.free.single.freePage(frame);
    count = 0;
    pmm.free.single.freePage(released);
    verify.require(std.meta.eql(pmm.state.getStatistics(), before), labels.PMM_FREE);
    try checkWrap();
}

fn checkWrap() !void {
    const state = pmm.state.getState();
    const previous = state.SearchStart;
    defer state.SearchStart = previous;
    const expected = pmm.state.firstFreeAtOrAfter(0) orelse @panic(labels.PMM_WRAP);
    state.SearchStart = layout.PHYSMAP_MAX_SIZE / sizes.PAGE_SIZE;
    const wrapped = try pmm.allocate.single.allocatePage();
    defer pmm.free.single.freePage(wrapped);
    verify.require(wrapped == expected and state.SearchStart == wrapped / sizes.PAGE_SIZE + 1, labels.PMM_WRAP);
}
