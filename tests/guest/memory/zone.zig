//! Disposable Zone Page Regressions

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.memory.fixtures;
const labels = @import("tests").guest.strings.memory.witnesses;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const Zone = memory.types.zone.layout.Zone;

var retained_zone: ?*Zone = null;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (retained_zone == null) retained_zone = try memory.zone.create.create(labels.ZONE_NAME, inputs.ZONE_REQUEST);
    const fixture = retained_zone.?;
    const name_length = memory.constants.zone.limits.NAME_CAPACITY - 1;
    verify.require(fixture.ElementSize == inputs.ZONE_CAPACITY and
        fixture.ElementsPerPage == inputs.ZONE_ELEMENTS and fixture.PageCount == 0 and fixture.inUse() == 0 and
        std.mem.eql(u8, fixture.getName(), labels.ZONE_NAME[0..name_length]), labels.ZONE_GEOMETRY);
    var allocations = [_]?*anyopaque{null} ** (inputs.ZONE_ELEMENTS + 1);
    defer {
        for (allocations) |allocation| {
            if (allocation) |pointer| memory.zone.alloc.zfree(fixture, pointer);
        }
        _ = memory.zone.gc.collect(fixture);
    }
    for (&allocations) |*allocation| {
        const pointer = try memory.zone.alloc.zallocZeroed(fixture);
        allocation.* = pointer;
        const bytes: [*]u8 = @ptrCast(pointer);
        verify.require(@intFromPtr(pointer) % memory.constants.zone.limits.ELEMENT_ALIGNMENT == 0 and
            std.mem.allEqual(u8, bytes[0..fixture.ElementSize], 0), labels.KALLOC_ZERO);
        @memset(bytes[0..fixture.ElementSize], inputs.DIRTY_BYTE);
    }
    verify.require(fixture.PageCount == 2 and fixture.inUse() == allocations.len and
        fixture.FullPages != null and fixture.FullPages.?.InUse == inputs.ZONE_ELEMENTS and
        fixture.PartialPages != null and fixture.PartialPages.?.InUse == 1, labels.ZONE_FULL);
    const released = allocations[0].?;
    memory.zone.alloc.zfree(fixture, released);
    allocations[0] = null;
    const reused = try memory.zone.alloc.zalloc(fixture);
    allocations[0] = reused;
    verify.require(reused == released and fixture.PageCount == 2 and
        fixture.inUse() == allocations.len and fixture.FullPages != null, labels.ZONE_REUSE);
    const foreign = try memory.kalloc.kalloc(inputs.ALLOCATION_CASES[0].Request);
    defer memory.kalloc.kfree(foreign, inputs.ALLOCATION_CASES[0].Request);
    const allocation_count = fixture.AllocationCount;
    const free_count = fixture.FreeCount;
    memory.zone.alloc.zfree(fixture, foreign);
    verify.require(fixture.AllocationCount == allocation_count and fixture.FreeCount == free_count and
        fixture.inUse() == allocations.len, labels.ZONE_FOREIGN);
    for (allocations[0..inputs.ZONE_ELEMENTS]) |allocation| memory.zone.alloc.zfree(fixture, allocation.?);
    @memset(allocations[0..inputs.ZONE_ELEMENTS], null);
    const before_partial = pmm.state.getStatistics();
    const partial_pages = memory.zone.gc.collect(fixture);
    const live: [*]const u8 = @ptrCast(allocations[inputs.ZONE_ELEMENTS].?);
    verify.require(partial_pages == 1 and fixture.PageCount == 1 and fixture.inUse() == 1 and
        fixture.FullPages == null and fixture.PartialPages != null and
        std.mem.allEqual(u8, live[0..fixture.ElementSize], inputs.DIRTY_BYTE) and
        pmm.state.getStatistics().FreePages == before_partial.FreePages + 1 and
        pmm.state.getStatistics().UsedPages + 1 == before_partial.UsedPages, labels.ZONE_COLLECT_LIVE);
    memory.zone.alloc.zfree(fixture, allocations[inputs.ZONE_ELEMENTS].?);
    allocations[inputs.ZONE_ELEMENTS] = null;
    const before_empty = pmm.state.getStatistics();
    const empty_pages = memory.zone.gc.collect(fixture);
    verify.require(empty_pages == 1 and fixture.PageCount == 0 and fixture.inUse() == 0 and
        fixture.PartialPages == null and fixture.FullPages == null and
        pmm.state.getStatistics().FreePages == before_empty.FreePages + 1 and
        pmm.state.getStatistics().UsedPages + 1 == before_empty.UsedPages and
        memory.zone.gc.collect(fixture) == 0, labels.ZONE_COLLECT_EMPTY);
    verify.require(memory.zone.gc.collect(memory.zone.bootstrap.getPageMetaZone()) == 0 and
        fixture.ElementsPerPage == common.constants.memory.sizes.PAGE_SIZE / fixture.ElementSize, labels.ZONE_META);
}
