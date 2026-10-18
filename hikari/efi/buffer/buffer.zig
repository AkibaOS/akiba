//! Hikari EFI Aligned Buffer Allocation

const std = @import("std");

const services = @import("hikari").efi.services;
const types = @import("hikari").efi.types;

pub fn allocate(boot_services: *services.boot.BootServices, size: usize, alignment: u32) ?types.buffer.AlignedBuffer {
    if (size == 0 or (alignment > 1 and (alignment & (alignment - 1)) != 0)) return null;
    const required_alignment: usize = @max(alignment, @alignOf(u64));
    const alignment_mask = required_alignment - 1;
    const allocation_size = std.math.add(usize, size, alignment_mask) catch return null;
    var allocation: [*]align(8) u8 = undefined;
    const allocation_status = boot_services.AllocatePool(.LoaderData, allocation_size, &allocation);
    if (types.base.isError(allocation_status)) return null;

    const allocation_address = @intFromPtr(allocation);
    const padded_address = std.math.add(usize, allocation_address, alignment_mask) catch {
        _ = boot_services.FreePool(allocation);
        return null;
    };
    const data_address = padded_address & ~alignment_mask;
    _ = std.math.add(usize, data_address, size) catch {
        _ = boot_services.FreePool(allocation);
        return null;
    };

    return .{
        .Allocation = allocation,
        .Data = @ptrFromInt(data_address),
        .Size = size,
    };
}

pub fn release(boot_services: *services.boot.BootServices, buffer: *types.buffer.AlignedBuffer) void {
    if (buffer.Size == 0) return;
    _ = boot_services.FreePool(buffer.Allocation);
    buffer.Size = 0;
}
