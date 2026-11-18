//! Checked Physical Page Release Regressions

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const labels = @import("tests").strings.memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const before = pmm.state.getStatistics();
    const owned = try pmm.allocate.contiguous.allocateContiguous(inputs.RANGE_PAGES);
    defer {
        for (0..inputs.RANGE_PAGES) |index| pmm.free.single.freePage(owned + index * sizes.PAGE_SIZE);
    }
    const allocated = pmm.state.getStatistics();
    const cursor = pmm.state.getState().SearchStart;
    verify.require(!pmm.free.range.releaseRange(owned, 0) and
        !pmm.free.single.releasePage(owned + inputs.SINGLE_BYTE) and
        !pmm.free.range.releaseRange(owned, std.math.maxInt(u64)) and
        !pmm.free.single.releasePage(0) and !pmm.free.single.releasePage(layout.PHYSMAP_MAX_SIZE) and
        pmm.state.getState().SearchStart == cursor and std.meta.eql(allocated, pmm.state.getStatistics()), labels.PMM_RELEASE_INVALID);
    const middle = owned + sizes.PAGE_SIZE;
    verify.require(pmm.free.range.releaseRange(middle, inputs.RANGE_PAGES - 2), labels.PMM_FREE);
    const partial = pmm.state.getStatistics();
    const partial_cursor = pmm.state.getState().SearchStart;
    const last = owned + (inputs.RANGE_PAGES - 1) * sizes.PAGE_SIZE;
    verify.require(!pmm.free.range.releaseRange(owned, inputs.RANGE_PAGES) and
        !pmm.free.single.releasePage(middle) and pmm.state.isAllocated(owned) and pmm.state.isAllocated(last) and
        pmm.state.getRole(middle) == .Free and pmm.state.getState().SearchStart == partial_cursor and
        std.meta.eql(partial, pmm.state.getStatistics()), labels.PMM_RELEASE_ATOMIC);
    verify.require(pmm.free.single.releasePage(owned) and pmm.free.single.releasePage(last) and
        std.meta.eql(before, pmm.state.getStatistics()), labels.PMM_FREE);
}
