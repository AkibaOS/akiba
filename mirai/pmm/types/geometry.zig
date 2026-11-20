//! Sparse Physical Memory Planning Types

const types = @import("mirai").pmm.types;

const MemoryRegion = types.region.MemoryRegion;
const Range = types.storage.layout.Range;

pub const Source = struct {
    Regions: []const MemoryRegion,
    PhysicalPages: u64,
    Position: usize = 0,
};

pub const Eligible = struct {
    Source: Source,
    Exclusions: []const Range,
    Remaining: Range = .{ .Start = 0, .End = 0 },
    Frames: Range = .{ .Start = 0, .End = 0 },
};

pub const Packer = struct {
    Source: Source,
    Remaining: Range = .{ .Start = 0, .End = 0 },
    UsedBytes: usize = 0,
};

pub const Placement = struct {
    Range: Range,
    Offset: usize,
    Stride: usize,
};

pub const Plan = struct {
    TotalPages: u64 = 0,
    EligiblePages: u64 = 0,
    MetadataPages: u64 = 0,
    PackedBytes: u64 = 0,
};
