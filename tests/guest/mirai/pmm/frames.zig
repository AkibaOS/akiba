//! Scratch Physical Frame Regressions

const std = @import("std");

const address = @import("utils").address;
const bits = @import("utils").bits;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const labels = @import("tests").strings.memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

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
            bits.operations.testBit(pmm.state.getState().Bitmap, frame / sizes.PAGE_SIZE), labels.PMM_FRAMES);
        for (frames[0 .. count - 1]) |other| verify.require(frame != other, labels.PMM_FRAMES);
    }
    const allocated = pmm.state.getStatistics();
    verify.require(allocated.FreePages + frames.len == before.FreePages and
        allocated.UsedPages == before.UsedPages + frames.len and
        allocated.TotalPages == before.TotalPages and allocated.ReservedPages == before.ReservedPages and
        allocated.WiredPages == before.WiredPages and
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
}
