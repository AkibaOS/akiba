//! Cold Sparse Metadata Emission Into Independent Frames

const common = @import("common");
const plan = @import("mirai").pmm.init.plan;
const regions = @import("mirai").pmm.init.regions;
const storage = @import("mirai").pmm.storage;
const types = @import("mirai").pmm.types;

const sizes = common.constants.memory.sizes;
const Frame = types.storage.Frame;
const MemoryRegion = types.region.MemoryRegion;
const Range = types.storage.Range;
const State = types.state.State;

pub fn build(
    memory_map: []const MemoryRegion,
    physical_limit: u64,
    exclusions: []const Range,
    context: anytype,
    comptime mapFrame: anytype,
) ?State {
    const geometry = plan.analyze(memory_map, physical_limit, exclusions) orelse return null;
    if (geometry.MetadataPages == 0 or geometry.MetadataPages > geometry.EligiblePages) return null;
    const source: types.geometry.Source = .{ .Regions = memory_map, .PhysicalPages = physical_limit / sizes.PAGE_SIZE };
    var eligible: types.geometry.Eligible = .{ .Source = source, .Exclusions = exclusions };
    var packer: types.geometry.Packer = .{ .Source = source };
    var first: ?*Frame = null;
    var tail: ?*Frame = null;
    while (plan.next(&packer)) |placement| {
        if (placement.Offset == 0) {
            const frame: *Frame = mapFrame(context, regions.takeEligible(&eligible).? * sizes.PAGE_SIZE);
            frame.Header = .{
                .Next = null,
                .Lower = null,
                .Higher = null,
                .FirstPage = placement.Range.Start,
                .EndPage = placement.Range.End,
                .UsedBytes = 0,
            };
            if (tail) |previous| previous.Header.Next = frame else first = frame;
            tail = frame;
        }
        const frame = tail.?;
        const record = storage.records.at(frame, placement.Offset);
        record.* = .{ .StartPage = placement.Range.Start, .PageCount = placement.Range.End - placement.Range.Start };
        const body = placement.Offset + @sizeOf(types.storage.Record);
        @memset(frame.Data[body .. placement.Offset + placement.Stride], 0);
        frame.Header.EndPage = placement.Range.End;
        frame.Header.UsedBytes = placement.Offset + placement.Stride;
    }
    const index: types.storage.Index = .{
        .Root = storage.index.balance(&first, geometry.MetadataPages),
        .PhysicalPages = source.PhysicalPages,
    };
    storage.access.assign(index, regions.lowReservation(source.PhysicalPages), .Reserved);
    for (exclusions) |range| storage.access.assign(index, range, .Reserved);
    markMetadata(index, source, exclusions, geometry.MetadataPages);
    const free_pages = geometry.EligiblePages - geometry.MetadataPages;
    return .{
        .Index = index,
        .Statistics = .{
            .TotalPages = geometry.TotalPages,
            .FreePages = free_pages,
            .ReservedPages = geometry.TotalPages - free_pages,
            .MetadataPages = geometry.MetadataPages,
            .MetadataBytes = geometry.PackedBytes,
        },
    };
}

fn markMetadata(index: types.storage.Index, source: types.geometry.Source, exclusions: []const Range, count: u64) void {
    var eligible: types.geometry.Eligible = .{ .Source = source, .Exclusions = exclusions };
    var remaining = count;
    while (remaining != 0) {
        const span = regions.nextEligible(&eligible).?;
        const pages = @min(remaining, span.End - span.Start);
        storage.access.assign(index, .{ .Start = span.Start, .End = span.Start + pages }, .Reserved);
        remaining -= pages;
    }
}
