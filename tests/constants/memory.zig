//! Memory Regression Inputs

const common = @import("common");
const kagami = @import("mirai").kagami;
const types = @import("tests").types.memory;

const protection = kagami.constants.protection;
const sizes = common.constants.memory.sizes;

pub const FRAME_COUNT: usize = 4;
pub const RANGE_PAGES: u64 = 4;
pub const ALIGNMENT_PAGES: u64 = 3;
pub const DIRTY_BYTE: u8 = 0xa7;
pub const UNCHANGED_BYTE: u8 = 0x5c;
pub const SINGLE_BYTE: usize = 1;
pub const HUGE_LOOKUP_OFFSET: u64 = 0x1234;
pub const ZONE_REQUEST: usize = 1001;
pub const ZONE_CAPACITY: usize = 1008;
pub const ZONE_ELEMENTS: usize = sizes.PAGE_SIZE / ZONE_CAPACITY;
pub const ZONE_GROWTH_PAGES: usize = 128;
pub const ZONE_VALIDITY_SIZE: usize = 64;
pub const ZONE_INTERIOR_OFFSET: usize = 8;
pub const ZONE_METADATA_PRESSURE_SLOTS: usize = 512;
pub const ZONE_PARTIAL_BUDGET: usize = 2;
pub const ALLOCATION_CASES = [_]types.AllocationCase{
    .{ .Request = 1, .Capacity = 16 },
    .{ .Request = 16, .Capacity = 16 },
    .{ .Request = 17, .Capacity = 32 },
    .{ .Request = 32, .Capacity = 32 },
    .{ .Request = 33, .Capacity = 64 },
    .{ .Request = 64, .Capacity = 64 },
    .{ .Request = 65, .Capacity = 128 },
    .{ .Request = 128, .Capacity = 128 },
    .{ .Request = 129, .Capacity = 256 },
    .{ .Request = 256, .Capacity = 256 },
    .{ .Request = 257, .Capacity = 512 },
    .{ .Request = 512, .Capacity = 512 },
    .{ .Request = 513, .Capacity = 1024 },
    .{ .Request = 1024, .Capacity = 1024 },
    .{ .Request = 1025, .Capacity = 2048 },
    .{ .Request = 2048, .Capacity = 2048 },
    .{ .Request = 2049, .Capacity = 4096 },
    .{ .Request = 4096, .Capacity = 4096 },
};
pub const MAP_ADDRESS: u64 = 0x2000000;
pub const MAP_NEIGHBOR: u64 = MAP_ADDRESS + sizes.PAGE_SIZE;
pub const MAP_BRANCH: u64 = MAP_ADDRESS + sizes.LARGE_PAGE_SIZE;
pub const MAP_DISTANT: u64 = MAP_ADDRESS + sizes.HUGE_PAGE_SIZE;
pub const MAP_RANGE_PAGES: u64 = 3;
pub const MAP_REJECTIONS = [_]types.MappingRejection{
    .{ .Address = MAP_ADDRESS + SINGLE_BYTE, .Protection = protection.USER_WRITE, .Failure = error.AddressNotAligned },
    .{ .Address = MAP_ADDRESS, .PhysicalOffset = SINGLE_BYTE, .Protection = protection.USER_WRITE, .Failure = error.AddressNotAligned },
    .{ .Address = common.constants.memory.layout.USER_SPACE_END + 1, .Protection = protection.USER_WRITE, .Failure = error.InvalidAddress },
    .{ .Address = common.constants.memory.layout.PHYSMAP_BASE, .Protection = protection.USER_WRITE, .Failure = error.PermissionDenied },
    .{ .Address = MAP_ADDRESS, .Protection = protection.WRITE, .Failure = error.PermissionDenied },
    .{ .Address = MAP_ADDRESS, .Protection = protection.USER_ALL, .Failure = error.PermissionDenied },
    .{ .Address = MAP_ADDRESS, .Protection = protection.USER_EXECUTE, .Failure = error.PermissionDenied },
    .{ .Address = MAP_ADDRESS, .Protection = protection.USER_WRITE | protection.NOCACHE, .Failure = error.PermissionDenied },
};
pub const FIRST_TABLE_PAGES: u64 = 4;
pub const BRANCH_TABLE_PAGES: u64 = 5;
pub const DISTANT_TABLE_PAGES: u64 = 7;
pub const USER_ADDRESS: u64 = 0x3000000;
pub const USER_NEIGHBOR: u64 = USER_ADDRESS + sizes.PAGE_SIZE;
pub const COPY_HALF: usize = 4;
pub const CROSS_ADDRESS: u64 = USER_NEIGHBOR - COPY_HALF;
pub const HOLE_ADDRESS: u64 = USER_NEIGHBOR + sizes.PAGE_SIZE - COPY_HALF;
pub const COPY_BYTES = [_]u8{ 0x11, 0x23, 0x35, 0x47, 0x59, 0x6b, 0x7d, 0x8f };
pub const COPY_REPLACEMENT = [_]u8{ 0x90, 0x82, 0x74, 0x66, 0x58, 0x4a, 0x3c, 0x2e };
pub const OVERLAP_BYTES = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
pub const OVERLAP_SHIFT: usize = 2;
pub const OVERLAP_LENGTH: usize = 12;
