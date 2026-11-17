//! Zone Allocation Failure And Recovery Regressions

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const labels = @import("tests").strings.memory;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

const sizes = common.constants.memory.sizes;
const Zone = memory.types.zone.Zone;

var retained_zone: ?*Zone = null;
var reserved = [_]?*anyopaque{null} ** inputs.ZONE_METADATA_PRESSURE_SLOTS;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    if (retained_zone == null) retained_zone = try memory.zone.create.create(labels.ZONE_FAILURE_NAME, sizes.PAGE_SIZE);
    const fixture = retained_zone.?;
    const metadata = memory.zone.bootstrap.getPageMetaZone();
    _ = memory.zone.gc.collect(metadata);
    zero(fixture, metadata);
    try metadataFailure(fixture, metadata);
    try partial(fixture, metadata);
}

fn zero(fixture: *Zone, metadata: *Zone) void {
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    var rejected = false;
    budget.arm(0);
    if (memory.zone.alloc.zalloc(fixture)) |unexpected| {
        budget.clear();
        memory.zone.alloc.zfree(fixture, unexpected);
        _ = memory.zone.gc.collect(fixture);
        _ = memory.zone.gc.collect(metadata);
    } else |failure| {
        budget.clear();
        rejected = failure == error.OutOfMemory;
    }
    verify.require(rejected and fixture.PageCount == 0 and fixture.inUse() == 0 and
        std.meta.eql(before, pmm.state.getStatistics()) and search == pmm.state.getState().SearchStart, labels.ZONE_ZERO_BUDGET);
}

fn metadataFailure(fixture: *Zone, metadata: *Zone) !void {
    var count: usize = 0;
    defer {
        budget.clear();
        for (&reserved) |*record| {
            if (record.*) |pointer| memory.zone.alloc.zfree(metadata, pointer);
            record.* = null;
        }
        _ = memory.zone.gc.collect(fixture);
        _ = memory.zone.gc.collect(metadata);
    }
    const before_pressure = pmm.state.getStatistics();
    while (metadata.PartialPages != null and count < reserved.len) : (count += 1) {
        reserved[count] = try memory.zone.alloc.zalloc(metadata);
    }
    verify.require(metadata.PartialPages == null and std.meta.eql(before_pressure, pmm.state.getStatistics()), labels.ZONE_METADATA_PRESSURE);
    const before = pmm.state.getStatistics();
    const metadata_pages = metadata.PageCount;
    const metadata_live = metadata.inUse();
    var rejected = false;
    budget.arm(1);
    if (memory.zone.alloc.zalloc(fixture)) |unexpected| {
        budget.clear();
        memory.zone.alloc.zfree(fixture, unexpected);
        _ = memory.zone.gc.collect(fixture);
        _ = memory.zone.gc.collect(metadata);
    } else |failure| {
        budget.clear();
        rejected = failure == error.OutOfMemory;
    }
    verify.require(rejected and fixture.PageCount == 0 and fixture.inUse() == 0 and metadata.PageCount == metadata_pages and
        metadata.inUse() == metadata_live and std.meta.eql(before, pmm.state.getStatistics()), labels.ZONE_METADATA_ROLLBACK);
}

fn partial(fixture: *Zone, metadata: *Zone) !void {
    const before = pmm.state.getStatistics();
    var allocations = [_]?*anyopaque{null} ** inputs.ZONE_GROWTH_PAGES;
    defer {
        budget.clear();
        for (allocations) |allocation| {
            if (allocation) |pointer| memory.zone.alloc.zfree(fixture, pointer);
        }
        _ = memory.zone.gc.collect(fixture);
        _ = memory.zone.gc.collect(metadata);
    }
    var count: usize = 0;
    var rejected = false;
    budget.arm(inputs.ZONE_PARTIAL_BUDGET);
    while (count < allocations.len) : (count += 1) {
        allocations[count] = memory.zone.alloc.zalloc(fixture) catch |failure| {
            rejected = failure == error.OutOfMemory;
            break;
        };
    }
    budget.clear();
    verify.require(rejected and count != 0 and count < allocations.len and fixture.inUse() == count, labels.ZONE_PARTIAL_FAILURE);
    for (&allocations) |*allocation| {
        if (allocation.*) |pointer| memory.zone.alloc.zfree(fixture, pointer);
        allocation.* = null;
    }
    _ = memory.zone.gc.collect(fixture);
    _ = memory.zone.gc.collect(metadata);
    const recovered = try memory.zone.alloc.zallocZeroed(fixture);
    const bytes: [*]const u8 = @ptrCast(recovered);
    const cleared = std.mem.allEqual(u8, bytes[0..sizes.PAGE_SIZE], 0);
    memory.zone.alloc.zfree(fixture, recovered);
    budget.arm(0);
    _ = memory.zone.gc.collect(fixture);
    _ = memory.zone.gc.collect(metadata);
    budget.clear();
    verify.require(cleared and fixture.PageCount == 0 and fixture.inUse() == 0 and
        std.meta.eql(before, pmm.state.getStatistics()), labels.ZONE_FAILURE_RECOVERY);
}
