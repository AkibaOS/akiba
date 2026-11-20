//! Canonical Physical Regions And Boot Exclusions

const std = @import("std");

const common = @import("common");
const limits = @import("mirai").pmm.constants.limits;
const types = @import("mirai").pmm.types;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const Eligible = types.geometry.Eligible;
const MemoryRegion = types.region.MemoryRegion;
const Range = types.storage.layout.Range;
const Source = types.geometry.Source;

pub fn validate(regions: []const MemoryRegion, physical_limit: u64, exclusions: []const Range) bool {
    if (regions.len == 0 or physical_limit == 0 or physical_limit > layout.PHYSMAP_MAX_SIZE or
        physical_limit & sizes.PAGE_MASK != 0) return false;
    var previous_end: u64 = 0;
    for (regions) |region| {
        if (region.BaseAddress < previous_end or region.Length == 0 or
            (region.BaseAddress | region.Length) & sizes.PAGE_MASK != 0 or
            region.Length > std.math.maxInt(u64) - region.BaseAddress) return false;
        switch (region.RegionType) {
            .Available, .Reserved, .ACPIReclaimable, .ACPINVS, .Bad, .LoaderData => {},
            else => return false,
        }
        previous_end = region.endAddress();
    }
    for (exclusions) |range| {
        if (range.Start >= range.End or range.End > physical_limit / sizes.PAGE_SIZE) return false;
    }
    return true;
}

pub fn lowReservation(physical_pages: u64) Range {
    return .{ .Start = 0, .End = @min(physical_pages, limits.KERNEL_RESERVED_PAGES) };
}

pub fn nextManaged(source: *Source) ?Range {
    return nextRegion(source, true);
}

fn included(region: MemoryRegion, include_loader: bool) bool {
    return region.isUsable() or (include_loader and region.RegionType == .LoaderData);
}

fn nextRegion(source: *Source, include_loader: bool) ?Range {
    while (source.Position < source.Regions.len) {
        const region = source.Regions[source.Position];
        source.Position += 1;
        const start = region.BaseAddress / sizes.PAGE_SIZE;
        if (start >= source.PhysicalPages) return null;
        if (!included(region, include_loader)) continue;
        var end = @min(source.PhysicalPages, start + region.pageCount());
        while (end < source.PhysicalPages and source.Position < source.Regions.len) {
            const adjacent = source.Regions[source.Position];
            if (!included(adjacent, include_loader) or adjacent.BaseAddress / sizes.PAGE_SIZE != end) break;
            source.Position += 1;
            end = @min(source.PhysicalPages, end + adjacent.pageCount());
        }
        return .{ .Start = start, .End = end };
    }
    return null;
}

pub fn nextEligible(eligible: *Eligible) ?Range {
    while (true) {
        if (eligible.Remaining.Start == eligible.Remaining.End) {
            eligible.Remaining = nextRegion(&eligible.Source, false) orelse return null;
        }
        const start = eligible.Remaining.Start;
        const stop = eligible.Remaining.End;
        const low = lowReservation(eligible.Source.PhysicalPages);
        var skip = if (start < low.End) @min(low.End, stop) else start;
        var end = stop;
        for (eligible.Exclusions) |range| {
            if (range.Start <= start and start < range.End) skip = @max(skip, @min(range.End, stop));
            if (range.Start > start) end = @min(end, range.Start);
        }
        if (skip > start) {
            eligible.Remaining.Start = skip;
            continue;
        }
        eligible.Remaining.Start = end;
        return .{ .Start = start, .End = end };
    }
}

pub fn takeEligible(eligible: *Eligible) ?u64 {
    if (eligible.Frames.Start == eligible.Frames.End) eligible.Frames = nextEligible(eligible) orelse return null;
    const page = eligible.Frames.Start;
    eligible.Frames.Start += 1;
    return page;
}
