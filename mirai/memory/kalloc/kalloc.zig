//! Kernel Allocator

const common = @import("common");
const constants = @import("mirai").memory.constants;
const errors = @import("mirai").memory.errors.allocation;
const heap = @import("mirai").memory.heap;
const strings = @import("mirai").memory.strings;
const types = @import("mirai").memory.types;
const zone = @import("mirai").memory.zone;

const names = strings.kalloc.names;
const zone_sizes = constants.kalloc.sizes.ZONE_SIZES;
const AllocationError = common.errors.memory.allocation.AllocationError;
const MemoryError = errors.AllocationError;
const Zone = types.zone.Zone;

var zones: [zone_sizes.len]?*Zone = [_]?*Zone{null} ** zone_sizes.len;
var initialized: bool = false;

pub fn init() AllocationError!void {
    if (initialized) return;
    if (!zone.bootstrap.isInitialized()) return AllocationError.NotInitialized;
    inline for (zone_sizes, 0..) |size, index| zones[index] = try zone.create.create(zoneName(size), size);
    initialized = true;
}

pub fn kalloc(size: usize) MemoryError!*anyopaque {
    if (!initialized) return AllocationError.NotInitialized;
    if (size == 0) return AllocationError.SizeTooLarge;
    const target_zone = getZoneForSize(size) orelse return heap.allocate.allocate(size, common.constants.memory.sizes.PAGE_SIZE);
    return zone.alloc.zalloc(target_zone);
}

pub fn kallocZeroed(size: usize) MemoryError!*anyopaque {
    if (!initialized) return AllocationError.NotInitialized;
    if (size == 0) return AllocationError.SizeTooLarge;
    const target_zone = getZoneForSize(size) orelse return heap.allocate.allocate(size, common.constants.memory.sizes.PAGE_SIZE);
    return zone.alloc.zallocZeroed(target_zone);
}

pub fn kfree(pointer: *anyopaque, size: usize) void {
    if (!initialized) return;
    if (heap.state.belongs(@intFromPtr(pointer))) {
        _ = heap.free.free(pointer, size);
        return;
    }
    const target_zone = getZoneForSize(size) orelse return;
    zone.alloc.zfree(target_zone, pointer);
}

pub fn supports(size: usize, alignment: usize) bool {
    if (!initialized or size == 0 or alignment == 0 or (alignment & (alignment - 1)) != 0) return false;
    const target_zone = getZoneForSize(size) orelse return false;
    return alignment <= target_zone.ElementSize;
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
