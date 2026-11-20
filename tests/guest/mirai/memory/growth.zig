//! Growable Zone Metadata Regressions

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.memory;
const labels = @import("tests").guest.strings.memory;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const sizes = common.constants.memory.sizes;
const Zone = memory.types.zone.layout.Zone;
const ZonePageMeta = memory.types.zone.layout.ZonePageMeta;

var retained_zone: ?*Zone = null;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (retained_zone == null) retained_zone = try memory.zone.create.create(labels.ZONE_GROWTH_NAME, sizes.PAGE_SIZE);
    const fixture = retained_zone.?;
    const metadata = memory.zone.bootstrap.getPageMetaZone();
    _ = memory.zone.gc.collect(metadata);
    const metadata_pages = metadata.PageCount;
    const before = pmm.state.getStatistics();
    var allocations = [_]?*anyopaque{null} ** inputs.ZONE_GROWTH_PAGES;
    defer {
        for (allocations) |allocation| {
            if (allocation) |pointer| memory.zone.alloc.zfree(fixture, pointer);
        }
        _ = memory.zone.gc.collect(fixture);
        _ = memory.zone.gc.collect(metadata);
    }
    for (&allocations, 0..) |*allocation, index| {
        const pointer = try memory.zone.alloc.zalloc(fixture);
        allocation.* = pointer;
        const bytes: [*]u8 = @ptrCast(pointer);
        @memset(bytes[0..sizes.PAGE_SIZE], @intCast(index + 1));
    }
    var retained = fixture.PageCount == allocations.len and fixture.inUse() == allocations.len;
    for (allocations, 0..) |allocation, index| {
        const pointer = allocation.?;
        const bytes: [*]const u8 = @ptrCast(pointer);
        retained = retained and @intFromPtr(pointer) % sizes.PAGE_SIZE == 0 and
            std.mem.allEqual(u8, bytes[0..sizes.PAGE_SIZE], @intCast(index + 1));
        for (allocations[0..index]) |other| retained = retained and pointer != other.?;
    }
    verify.require(retained, labels.ZONE_GROWTH);
    verify.require(metadata.PageCount > metadata_pages, labels.ZONE_METADATA_GROWTH);
    headers(metadata);
    const retired = allocations[0].?;
    const before_targeted = pmm.state.getStatistics();
    const grown_metadata = metadata.PageCount;
    var targeted: usize = 0;
    for (allocations[0..inputs.ZONE_TARGETED_PAGES], 0..) |allocation, index| {
        const pointer = allocation.?;
        memory.zone.alloc.zfree(fixture, pointer);
        allocations[index] = null;
        targeted += memory.zone.gc.collectPage(fixture, pointer);
    }
    for (allocations[inputs.ZONE_TARGETED_PAGES..], inputs.ZONE_TARGETED_PAGES..) |allocation, index| {
        const bytes: [*]const u8 = @ptrCast(allocation.?);
        retained = retained and memory.zone.alloc.owns(fixture, allocation.?) and
            std.mem.allEqual(u8, bytes[0..sizes.PAGE_SIZE], @intCast(index + 1));
    }
    const after_targeted = pmm.state.getStatistics();
    verify.require(retained and targeted > inputs.ZONE_TARGETED_PAGES and metadata.PageCount < grown_metadata and
        fixture.PageCount == inputs.ZONE_GROWTH_PAGES - inputs.ZONE_TARGETED_PAGES and
        after_targeted.FreePages == before_targeted.FreePages + targeted, labels.ZONE_TARGETED_RELEASE);
    for (&allocations) |*allocation| {
        if (allocation.*) |pointer| memory.zone.alloc.zfree(fixture, pointer);
        allocation.* = null;
    }
    const released = memory.zone.gc.collect(fixture);
    const released_metadata = memory.zone.gc.collect(metadata);
    const after = pmm.state.getStatistics();
    verify.require(released == inputs.ZONE_GROWTH_PAGES - inputs.ZONE_TARGETED_PAGES and released_metadata != 0 and
        fixture.PageCount == 0 and fixture.inUse() == 0 and metadata.PageCount == metadata_pages and
        !memory.zone.alloc.owns(fixture, retired) and before.FreePages == after.FreePages and
        before.UsedPages == after.UsedPages, labels.ZONE_GROWTH_RELEASE);
    const reused = try memory.zone.alloc.zallocZeroed(fixture);
    const bytes: [*]const u8 = @ptrCast(reused);
    const cleared = memory.zone.alloc.owns(fixture, reused) and std.mem.allEqual(u8, bytes[0..sizes.PAGE_SIZE], 0);
    memory.zone.alloc.zfree(fixture, reused);
    _ = memory.zone.gc.collect(fixture);
    _ = memory.zone.gc.collect(metadata);
    const recovered = pmm.state.getStatistics();
    verify.require(cleared and fixture.PageCount == 0 and before.FreePages == recovered.FreePages and
        before.UsedPages == recovered.UsedPages, labels.ZONE_GROWTH_REUSE);
}

fn headers(metadata: *Zone) void {
    const freed = metadata.FreeCount;
    const live = metadata.inUse();
    var count: usize = 0;
    var rejected = true;
    const roots = [_]?*ZonePageMeta{ metadata.PartialPages, metadata.FullPages };
    for (roots) |root| {
        var current = root;
        while (current) |meta| {
            const next = meta.Next;
            if (@intFromPtr(meta) == meta.PageVirtual) {
                const pointer: *anyopaque = @ptrCast(meta);
                memory.zone.alloc.zfree(metadata, pointer);
                rejected = rejected and !memory.zone.alloc.owns(metadata, pointer) and meta.Zone == metadata and
                    meta.PageVirtual == @intFromPtr(meta);
                count += 1;
            }
            current = next;
        }
    }
    verify.require(rejected and count != 0 and metadata.FreeCount == freed and metadata.inUse() == live, labels.ZONE_METADATA_HEADER);
}
