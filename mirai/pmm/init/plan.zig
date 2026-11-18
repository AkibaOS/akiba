//! Exact Sparse Metadata Dry Run

const common = @import("common");
const geometry = @import("mirai").pmm.constants.storage;
const records = @import("mirai").pmm.storage.records;
const regions = @import("mirai").pmm.init.regions;
const types = @import("mirai").pmm.types;

const sizes = common.constants.memory.sizes;
const MemoryRegion = types.region.MemoryRegion;
const Packer = types.geometry.Packer;
const Plan = types.geometry.Plan;
const Placement = types.geometry.Placement;
const Range = types.storage.Range;

pub fn analyze(memory_map: []const MemoryRegion, physical_limit: u64, exclusions: []const Range) ?Plan {
    if (!regions.validate(memory_map, physical_limit, exclusions)) return null;
    const source: types.geometry.Source = .{ .Regions = memory_map, .PhysicalPages = physical_limit / sizes.PAGE_SIZE };
    var packer: Packer = .{ .Source = source };
    var plan: Plan = .{};
    while (next(&packer)) |placement| {
        if (placement.Offset == 0) {
            plan.MetadataPages += 1;
            plan.PackedBytes += geometry.FRAME_HEADER_BYTES;
        }
        plan.PackedBytes += placement.Stride;
        plan.TotalPages += placement.Range.End - placement.Range.Start;
    }
    var eligible: types.geometry.Eligible = .{ .Source = source, .Exclusions = exclusions };
    while (regions.nextEligible(&eligible)) |range| plan.EligiblePages += range.End - range.Start;
    return plan;
}

pub fn next(packer: *Packer) ?Placement {
    if (packer.Remaining.Start == packer.Remaining.End) {
        packer.Remaining = regions.nextManaged(&packer.Source) orelse return null;
    }
    if (geometry.FRAME_DATA_BYTES - packer.UsedBytes < geometry.MIN_RECORD_BYTES) packer.UsedBytes = 0;
    const available_bytes = geometry.FRAME_DATA_BYTES - packer.UsedBytes - geometry.RECORD_HEADER_BYTES;
    const page_count = @min(packer.Remaining.End - packer.Remaining.Start, available_bytes * geometry.PAGES_PER_BYTE);
    const start = packer.Remaining.Start;
    const stride = records.stride(page_count);
    const offset = packer.UsedBytes;
    packer.Remaining.Start += page_count;
    packer.UsedBytes += stride;
    return .{ .Range = .{ .Start = start, .End = start + page_count }, .Offset = offset, .Stride = stride };
}
