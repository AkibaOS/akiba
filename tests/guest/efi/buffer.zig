//! Hikari EFI Buffer Ownership Guest Regressions

const std = @import("std");

const base = @import("hikari").efi.types.base;
const buffer = @import("hikari").efi.buffer;
const convention = @import("hikari").efi.constants.convention;
const inputs = @import("tests").fixtures.constants.hikari;
const labels = @import("tests").guest.strings.hikari.expectations;
const memory = @import("hikari").efi.types.memory;
const services = @import("hikari").efi.types.services;
const status = @import("hikari").efi.constants.status.codes;
const storage = @import("hikari").efi.types.buffer.claims;
const types = @import("tests").guest.types.hikari.fixtures;
const verify = @import("tests").guest.support.verify;

var pool: types.PoolState = .{};

pub fn run() void {
    var boot_services: services.boot.BootServices = undefined;
    boot_services.AllocatePool = allocatePool;
    boot_services.FreePool = freePool;
    pool = .{};
    const storage_address = @intFromPtr(&pool.Storage);
    var owned: storage.AlignedBuffer = .{};
    if (!buffer.allocate(&boot_services, inputs.BUFFER_BYTES, inputs.POOL_ALIGNMENT, &owned)) verify.failure(error.AllocationFailed);
    @memset(owned.Data[0..owned.Size], inputs.BUFFER_VALUE);
    verify.require(pool.AllocateCalls == 1 and pool.FreeCalls == 0 and
        pool.PoolType == memory.MemoryType.LoaderData and pool.RequestedBytes == inputs.ALLOCATION_BYTES and
        @intFromPtr(owned.Pool.Allocation.?) == storage_address + inputs.POOL_OFFSET and
        @intFromPtr(owned.Data) == storage_address + inputs.BUFFER_OFFSET and owned.Size == inputs.BUFFER_BYTES and
        std.mem.allEqual(u8, pool.Storage[0..inputs.BUFFER_OFFSET], inputs.POOL_GUARD) and
        std.mem.allEqual(u8, pool.Storage[inputs.BUFFER_OFFSET..][0..inputs.BUFFER_BYTES], inputs.BUFFER_VALUE) and
        std.mem.allEqual(u8, pool.Storage[inputs.BUFFER_OFFSET + inputs.BUFFER_BYTES ..], inputs.POOL_GUARD), labels.BUFFER_ALIGNMENT);

    const raw = owned.Pool.Allocation;
    pool.FailFree = true;
    const refused = !buffer.release(&boot_services, &owned) and owned.Pool.Allocation == raw and owned.Size == inputs.BUFFER_BYTES and pool.FreeCalls == 1;
    pool.FailFree = false;
    verify.require(buffer.release(&boot_services, &owned) and refused and owned.Pool.isEmpty() and owned.Size == 0 and pool.FreeCalls == 2 and
        pool.FreedAddress == storage_address + inputs.POOL_OFFSET, labels.BUFFER_RELEASE);
    verify.require(buffer.release(&boot_services, &owned) and owned.Pool.isEmpty() and pool.FreeCalls == 2, labels.BUFFER_DOUBLE_RELEASE);

    pool = .{};
    verify.require(!buffer.allocate(&boot_services, 0, inputs.POOL_ALIGNMENT, &owned) and
        !buffer.allocate(&boot_services, inputs.BUFFER_BYTES, 3, &owned) and
        !buffer.allocate(&boot_services, std.math.maxInt(usize), 8, &owned) and owned.Pool.Allocation == null and
        pool.AllocateCalls == 0 and pool.FreeCalls == 0, labels.BUFFER_REJECTIONS);

    pool = .{ .FailAllocation = true };
    verify.require(!buffer.allocate(&boot_services, inputs.BUFFER_BYTES, 1, &owned) and owned.Pool.Allocation == null and
        pool.AllocateCalls == 1 and pool.RequestedBytes == 30 and pool.FreeCalls == 0, labels.BUFFER_FAILURE);

    const padding = failedView(&boot_services, std.math.maxInt(usize) - 7, 16);
    const extent = failedView(&boot_services, std.math.maxInt(usize) - 15, 8);
    const missing = failedView(&boot_services, null, inputs.POOL_ALIGNMENT);
    verify.require(padding and extent and missing, labels.BUFFER_ADDRESS_OVERFLOW);
}

fn failedView(boot_services: *services.boot.BootServices, address: ?usize, alignment: u32) bool {
    pool = .{ .OverrideAddress = address, .OmitOutput = address == null };
    var owned: storage.AlignedBuffer = .{};
    const no_view = !buffer.allocate(boot_services, inputs.BUFFER_BYTES, alignment, &owned) and owned.Size == 0;
    const no_release = !buffer.release(boot_services, &owned);
    const no_retry = !buffer.allocate(boot_services, inputs.BUFFER_BYTES, alignment, &owned);
    return no_view and no_release and no_retry and owned.Pool.Allocation == null and owned.Pool.Untrusted and
        pool.AllocateCalls == 1 and pool.FreeCalls == 0;
}

fn allocatePool(pool_type: memory.MemoryType, size: usize, allocation: *[*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    pool.AllocateCalls += 1;
    pool.RequestedBytes = size;
    pool.PoolType = pool_type;
    if (pool.FailAllocation) return status.OUT_OF_RESOURCES;
    if (!pool.OmitOutput) {
        const address = pool.OverrideAddress orelse @intFromPtr(&pool.Storage) + inputs.POOL_OFFSET;
        allocation.* = @ptrFromInt(address);
    }
    return status.SUCCESS;
}

fn freePool(allocation: [*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    pool.FreeCalls += 1;
    pool.FreedAddress = @intFromPtr(allocation);
    return if (pool.FailFree) status.DEVICE_ERROR else status.SUCCESS;
}
