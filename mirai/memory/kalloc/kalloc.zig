//! Kernel Allocator

const common = @import("common");

const constants = @import("../constants/constants.zig");
const strings = @import("../strings/strings.zig");
const types = @import("../types/types.zig");
const zone = @import("../zone/zone.zig");

const names = strings.kalloc.names;
const zone_sizes = constants.kalloc.sizes.ZONE_SIZES;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Zone = types.zone.Zone;

var zones: [zone_sizes.len]?*Zone = [_]?*Zone{null} ** zone_sizes.len;
var initialized: bool = false;

pub fn init() AllocationError!void {
    if (initialized) return;
    if (!zone.bootstrap.isInitialized()) return AllocationError.NotInitialized;

    inline for (zone_sizes, 0..) |size, index| {
        zones[index] = try zone.create.create(zoneName(size), size);
    }

    initialized = true;
}

pub fn kalloc(size: usize) AllocationError!*anyopaque {
    if (!initialized) return AllocationError.NotInitialized;
    if (size == 0) return AllocationError.SizeTooLarge;

    const target_zone = getZoneForSize(size) orelse return AllocationError.SizeTooLarge;
    return zone.alloc.zalloc(target_zone) catch AllocationError.OutOfMemory;
}

pub fn kallocZeroed(size: usize) AllocationError!*anyopaque {
    if (!initialized) return AllocationError.NotInitialized;
    if (size == 0) return AllocationError.SizeTooLarge;

    const target_zone = getZoneForSize(size) orelse return AllocationError.SizeTooLarge;
    return zone.alloc.zallocZeroed(target_zone) catch AllocationError.OutOfMemory;
}

pub fn kfree(pointer: *anyopaque, size: usize) void {
    if (!initialized) return;
    const target_zone = getZoneForSize(size) orelse return;
    zone.alloc.zfree(target_zone, pointer);
}

fn getZoneForSize(size: usize) ?*Zone {
    inline for (zone_sizes, 0..) |zone_size, index| {
        if (size <= zone_size) return zones[index];
    }
    return null;
}

fn zoneName(comptime size: usize) []const u8 {
    return switch (size) {
        16 => names.ZONE_16,
        32 => names.ZONE_32,
        64 => names.ZONE_64,
        128 => names.ZONE_128,
        256 => names.ZONE_256,
        512 => names.ZONE_512,
        1024 => names.ZONE_1024,
        2048 => names.ZONE_2048,
        4096 => names.ZONE_4096,
        else => names.ZONE_UNKNOWN,
    };
}
