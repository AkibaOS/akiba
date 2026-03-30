//! Kernel Allocator

const types = @import("../zone/types/types.zig");
const Zone = types.Zone;

const create_mod = @import("../zone/create/create.zig");
const alloc_mod = @import("../zone/alloc/alloc.zig");
const bootstrap = @import("../zone/bootstrap/bootstrap.zig");

pub const sizes = [_]usize{ 16, 32, 64, 128, 256, 512, 1024, 2048, 4096 };
const zone_count = sizes.len;

var zones: [zone_count]?*Zone = [_]?*Zone{null} ** zone_count;
var initialized: bool = false;

pub const AllocError = error{
    NotInitialized,
    SizeTooLarge,
    OutOfMemory,
};

pub fn init() !void {
    if (initialized) return;
    if (!bootstrap.is_initialized()) return error.NotInitialized;

    inline for (sizes, 0..) |size, i| {
        zones[i] = try create_mod.create(zone_name(size), size);
    }

    initialized = true;
}

pub fn kalloc(size: usize) AllocError!*anyopaque {
    if (!initialized) return AllocError.NotInitialized;
    if (size == 0) return AllocError.SizeTooLarge;

    const zone = get_zone_for_size(size) orelse return AllocError.SizeTooLarge;
    return alloc_mod.zalloc(zone) catch AllocError.OutOfMemory;
}

pub fn kalloc_zeroed(size: usize) AllocError!*anyopaque {
    if (!initialized) return AllocError.NotInitialized;
    if (size == 0) return AllocError.SizeTooLarge;

    const zone = get_zone_for_size(size) orelse return AllocError.SizeTooLarge;
    return alloc_mod.zalloc_zeroed(zone) catch AllocError.OutOfMemory;
}

pub fn kfree(ptr: *anyopaque, size: usize) void {
    if (!initialized) return;
    const zone = get_zone_for_size(size) orelse return;
    alloc_mod.zfree(zone, ptr);
}

fn get_zone_for_size(size: usize) ?*Zone {
    inline for (sizes, 0..) |zone_size, i| {
        if (size <= zone_size) return zones[i];
    }
    return null;
}

fn zone_name(comptime size: usize) []const u8 {
    return switch (size) {
        16 => "kalloc.16",
        32 => "kalloc.32",
        64 => "kalloc.64",
        128 => "kalloc.128",
        256 => "kalloc.256",
        512 => "kalloc.512",
        1024 => "kalloc.1024",
        2048 => "kalloc.2048",
        4096 => "kalloc.4096",
        else => "kalloc.unknown",
    };
}
