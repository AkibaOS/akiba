//! Scratch Physical Range Regressions

const std = @import("std");

const address = @import("utils").address;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.memory;
const labels = @import("tests").strings.memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const sizes = common.constants.memory.sizes;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const before = pmm.state.getStatistics();
    rejectEmpty();
    rejectImpossibleAlignment();
    const contiguous = try pmm.allocate.contiguous.allocateContiguousZeroed(inputs.RANGE_PAGES);
    var owns_contiguous = true;
    defer if (owns_contiguous) pmm.free.range.freeRange(contiguous, inputs.RANGE_PAGES);
    const bytes: [*]u8 = @ptrFromInt(address.translate.physToVirt(contiguous));
    verify.require((contiguous & sizes.PAGE_MASK) == 0 and
        std.mem.allEqual(u8, bytes[0 .. inputs.RANGE_PAGES * sizes.PAGE_SIZE], 0), labels.PMM_RANGE);
    var index: u64 = 0;
    while (index < inputs.RANGE_PAGES) : (index += 1) {
        verify.require(pmm.state.isAllocated(contiguous + index * sizes.PAGE_SIZE), labels.PMM_RANGE);
    }
    @memset(bytes[0 .. inputs.RANGE_PAGES * sizes.PAGE_SIZE], inputs.DIRTY_BYTE);
    const aligned = try pmm.allocate.contiguous.allocateAligned(inputs.RANGE_PAGES, inputs.ALIGNMENT_PAGES);
    var owns_aligned = true;
    defer if (owns_aligned) pmm.free.range.freeRange(aligned, inputs.RANGE_PAGES);
    verify.require(aligned % (inputs.ALIGNMENT_PAGES * sizes.PAGE_SIZE) == 0 and
        (aligned + inputs.RANGE_PAGES * sizes.PAGE_SIZE <= contiguous or
            contiguous + inputs.RANGE_PAGES * sizes.PAGE_SIZE <= aligned), labels.PMM_ALIGNED);
    const allocated = pmm.state.getStatistics();
    verify.require(allocated.FreePages + 2 * inputs.RANGE_PAGES == before.FreePages and
        allocated.UsedPages == before.UsedPages + 2 * inputs.RANGE_PAGES, labels.PMM_COUNTS);
    pmm.free.range.freeRange(aligned, inputs.RANGE_PAGES);
    owns_aligned = false;
    pmm.free.range.freeRange(contiguous, inputs.RANGE_PAGES);
    owns_contiguous = false;
    const reused = try pmm.allocate.contiguous.allocateContiguousZeroed(inputs.RANGE_PAGES);
    var owns_reused = true;
    defer if (owns_reused) pmm.free.range.freeRange(reused, inputs.RANGE_PAGES);
    verify.require(reused == contiguous, labels.PMM_REUSE);
    const zeroed: [*]const u8 = @ptrFromInt(address.translate.physToVirt(reused));
    verify.require(std.mem.allEqual(u8, zeroed[0 .. inputs.RANGE_PAGES * sizes.PAGE_SIZE], 0), labels.PMM_ZERO);
    pmm.free.range.freeRange(reused, inputs.RANGE_PAGES);
    owns_reused = false;
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.PMM_FREE);
}

fn rejectImpossibleAlignment() void {
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const allocated = pmm.allocate.contiguous.allocateAligned(1, std.math.maxInt(u64));
    if (allocated) |unexpected| {
        pmm.free.single.freePage(unexpected);
        verify.require(false, labels.PMM_REJECTIONS);
    } else |failure| {
        verify.require(failure == error.OutOfMemory and std.meta.eql(before, pmm.state.getStatistics()) and
            search == pmm.state.getState().SearchStart, labels.PMM_REJECTIONS);
    }
}

fn rejectEmpty() void {
    const before = pmm.state.getStatistics();
    var rejected_count = false;
    if (pmm.allocate.contiguous.allocateContiguous(0)) |unexpected| {
        pmm.free.range.freeRange(unexpected, 0);
    } else |failure| {
        rejected_count = failure == error.InvalidSize;
    }
    var rejected_aligned_count = false;
    if (pmm.allocate.contiguous.allocateAligned(0, inputs.ALIGNMENT_PAGES)) |_| {} else |failure| {
        rejected_aligned_count = failure == error.InvalidSize;
    }
    var rejected_alignment = false;
    if (pmm.allocate.contiguous.allocateAligned(inputs.RANGE_PAGES, 0)) |unexpected| {
        pmm.free.range.freeRange(unexpected, inputs.RANGE_PAGES);
    } else |failure| {
        rejected_alignment = failure == error.InvalidSize;
    }
    verify.require(rejected_count and rejected_aligned_count and rejected_alignment and
        std.meta.eql(before, pmm.state.getStatistics()), labels.PMM_REJECTIONS);
}
