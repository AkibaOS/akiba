//! Owned Physical Range Reservation Regressions

const std = @import("std");

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
    const owned = try pmm.allocate.contiguous.allocateContiguous(inputs.RANGE_PAGES);
    var owns_range = true;
    defer if (owns_range) pmm.free.range.freeRange(owned, inputs.RANGE_PAGES);
    const allocated = pmm.state.getStatistics();
    pmm.free.range.freeRange(owned, 0);
    pmm.init.setup.reservePhysicalRange(owned + inputs.SINGLE_BYTE, 0);
    verify.require(std.meta.eql(allocated, pmm.state.getStatistics()), labels.PMM_RESERVE_EMPTY);
    pmm.free.range.freeRange(owned + sizes.PAGE_SIZE, inputs.RANGE_PAGES - 2);
    const holes = pmm.state.getStatistics();
    verify.require(holes.FreePages == allocated.FreePages + inputs.RANGE_PAGES - 2, labels.PMM_COUNTS);
    pmm.init.setup.reservePhysicalRange(owned + sizes.PAGE_SIZE + inputs.SINGLE_BYTE, sizes.PAGE_SIZE);
    verify.require(std.meta.eql(allocated, pmm.state.getStatistics()), labels.PMM_RESERVE);
    pmm.init.setup.reservePhysicalRange(owned + inputs.SINGLE_BYTE, inputs.RANGE_PAGES * sizes.PAGE_SIZE - 2 * inputs.SINGLE_BYTE);
    pmm.init.setup.reservePhysicalRange(owned, inputs.RANGE_PAGES * sizes.PAGE_SIZE);
    verify.require(std.meta.eql(allocated, pmm.state.getStatistics()), labels.PMM_RESERVE);
    var index: u64 = 0;
    while (index < inputs.RANGE_PAGES) : (index += 1) {
        verify.require(bits.operations.testBit(pmm.state.getState().Bitmap, owned / sizes.PAGE_SIZE + index), labels.PMM_RESERVE);
    }
    pmm.free.range.freeRange(owned, inputs.RANGE_PAGES);
    owns_range = false;
    pmm.free.range.freeRange(owned, inputs.RANGE_PAGES);
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.PMM_FREE);
}
