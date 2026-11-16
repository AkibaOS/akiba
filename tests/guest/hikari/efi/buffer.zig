//! Hikari EFI Buffer Ownership Guest Regressions

const std = @import("std");

const base = @import("hikari").efi.types.base;
const buffer = @import("hikari").efi.buffer;
const convention = @import("hikari").efi.constants.convention;
const inputs = @import("tests").constants.hikari;
const labels = @import("tests").strings.hikari;
const memory = @import("hikari").efi.types.memory;
const services = @import("hikari").efi.types.services;
const status = @import("hikari").efi.constants.status;
const types = @import("tests").types.hikari;
const verify = @import("tests").verify;

var pool: types.PoolState = .{};

pub fn run() void {
    var boot_services: services.boot.BootServices = undefined;
    boot_services.AllocatePool = allocatePool;
    boot_services.FreePool = freePool;
    pool = .{};
    const storage_address = @intFromPtr(&pool.Storage);
    var owned = buffer.allocate(&boot_services, inputs.BUFFER_BYTES, inputs.POOL_ALIGNMENT).?;
    @memset(owned.Data[0..owned.Size], inputs.BUFFER_VALUE);
    verify.require(pool.AllocateCalls == 1 and pool.FreeCalls == 0 and
        pool.PoolType == memory.MemoryType.LoaderData and pool.RequestedBytes == inputs.ALLOCATION_BYTES and
        @intFromPtr(owned.Allocation) == storage_address + inputs.POOL_OFFSET and
        @intFromPtr(owned.Data) == storage_address + inputs.BUFFER_OFFSET and owned.Size == inputs.BUFFER_BYTES and
        std.mem.allEqual(u8, pool.Storage[0..inputs.BUFFER_OFFSET], inputs.POOL_GUARD) and
        std.mem.allEqual(u8, pool.Storage[inputs.BUFFER_OFFSET..][0..inputs.BUFFER_BYTES], inputs.BUFFER_VALUE) and
        std.mem.allEqual(u8, pool.Storage[inputs.BUFFER_OFFSET + inputs.BUFFER_BYTES ..], inputs.POOL_GUARD), labels.BUFFER_ALIGNMENT);

    buffer.release(&boot_services, &owned);
    verify.require(owned.Size == 0 and pool.FreeCalls == 1 and
        pool.FreedAddress == storage_address + inputs.POOL_OFFSET, labels.BUFFER_RELEASE);
    buffer.release(&boot_services, &owned);
    verify.require(owned.Size == 0 and pool.FreeCalls == 1, labels.BUFFER_DOUBLE_RELEASE);

    pool = .{};
    verify.require(buffer.allocate(&boot_services, 0, inputs.POOL_ALIGNMENT) == null and
        buffer.allocate(&boot_services, inputs.BUFFER_BYTES, 3) == null and
        buffer.allocate(&boot_services, std.math.maxInt(usize), 8) == null and
        pool.AllocateCalls == 0 and pool.FreeCalls == 0, labels.BUFFER_REJECTIONS);

    pool = .{ .FailAllocation = true };
    verify.require(buffer.allocate(&boot_services, inputs.BUFFER_BYTES, 1) == null and
        pool.AllocateCalls == 1 and pool.RequestedBytes == 30 and pool.FreeCalls == 0, labels.BUFFER_FAILURE);

    pool = .{ .OverrideAddress = std.math.maxInt(usize) - 7 };
    const padding_released = buffer.allocate(&boot_services, inputs.BUFFER_BYTES, 16) == null and
        pool.AllocateCalls == 1 and pool.FreeCalls == 1 and pool.FreedAddress == pool.OverrideAddress;
    pool = .{ .OverrideAddress = std.math.maxInt(usize) - 15 };
    verify.require(padding_released and buffer.allocate(&boot_services, inputs.BUFFER_BYTES, 8) == null and
        pool.AllocateCalls == 1 and pool.FreeCalls == 1 and pool.FreedAddress == pool.OverrideAddress, labels.BUFFER_ADDRESS_OVERFLOW);
}

fn allocatePool(pool_type: memory.MemoryType, size: usize, allocation: *[*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    pool.AllocateCalls += 1;
    pool.RequestedBytes = size;
    pool.PoolType = pool_type;
    if (pool.FailAllocation) return status.OUT_OF_RESOURCES;
    const address = pool.OverrideAddress orelse @intFromPtr(&pool.Storage) + inputs.POOL_OFFSET;
    allocation.* = @ptrFromInt(address);
    return status.SUCCESS;
}

fn freePool(allocation: [*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    pool.FreeCalls += 1;
    pool.FreedAddress = @intFromPtr(allocation);
    return status.SUCCESS;
}
