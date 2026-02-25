//! Physical Memory Manager Types

pub const page = @import("page.zig");
pub const region = @import("region.zig");
pub const statistics = @import("statistics.zig");

pub const PhysicalPage = page.PhysicalPage;
pub const PageFlags = page.PhysicalPage.PageFlags;
pub const MemoryRegion = region.MemoryRegion;
pub const RegionType = region.MemoryRegion.RegionType;
pub const Statistics = statistics.Statistics;
