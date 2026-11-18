//! Hikari EFI Pool Ownership And Aligned Buffers

const std = @import("std");

const efi = @import("hikari").efi;

const AlignedBuffer = efi.types.buffer.AlignedBuffer;
const BootServices = efi.types.services.boot.BootServices;
const PoolClaim = efi.types.buffer.PoolClaim;
const status = efi.constants.status;

pub fn recordPool(owner: *PoolClaim, allocation: ?[*]align(8) u8, size: usize) bool {
    if (!owner.isEmpty()) return false;
    const address = @intFromPtr(allocation);
    if (allocation == null or address % @alignOf(u64) != 0 or size == 0 or size - 1 > std.math.maxInt(usize) - address) {
        owner.Untrusted = true;
        return false;
    }
    owner.Allocation = allocation;
    return true;
}

pub fn allocatePool(services: *BootServices, size: usize, owner: *PoolClaim) bool {
    if (size == 0 or !owner.isEmpty()) return false;
    var allocation: ?[*]align(8) u8 = null;
    if (services.AllocatePool(.LoaderData, size, @ptrCast(&allocation)) != status.SUCCESS) return false;
    return recordPool(owner, allocation, size);
}

pub fn allocate(services: *BootServices, size: usize, alignment: u32, buffer: *AlignedBuffer) bool {
    if (size == 0 or (alignment > 1 and (alignment & (alignment - 1) != 0))) return false;
    const required_alignment: usize = @max(alignment, @alignOf(u64));
    const alignment_mask = required_alignment - 1;
    const allocation_size = std.math.add(usize, size, alignment_mask) catch return false;
    if (!allocatePool(services, allocation_size, &buffer.Pool)) return false;
    const padded_address = std.math.add(usize, @intFromPtr(buffer.Pool.Allocation.?), alignment_mask) catch return false;
    const data_address = padded_address & ~alignment_mask;
    _ = std.math.add(usize, data_address, size) catch return false;
    buffer.Data = @ptrFromInt(data_address);
    buffer.Size = size;
    return true;
}

pub fn releasePool(services: *BootServices, owner: *PoolClaim) bool {
    const allocation = owner.Allocation orelse return !owner.Untrusted;
    if (services.FreePool(allocation) != status.SUCCESS) return false;
    owner.Allocation = null;
    return !owner.Untrusted;
}

pub fn release(services: *BootServices, buffer: *AlignedBuffer) bool {
    if (!releasePool(services, &buffer.Pool)) return false;
    buffer.* = .{};
    return true;
}
