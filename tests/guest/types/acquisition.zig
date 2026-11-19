//! Hikari Disk Acquisition Regression Types

const constants = @import("tests").guest.constants.acquisition;

pub const PoolSlot = struct {
    Bytes: [constants.POOL_BYTES]u8 align(constants.IO_ALIGNMENT) = @splat(constants.POOL_GUARD),
    InUse: bool = false,
    Size: usize = 0,
};

pub const BlockRead = struct {
    LBA: u64,
    Bytes: usize,
    Address: usize,
};

pub const Device = struct {
    Disk: [constants.DISK_BYTES]u8 align(constants.IO_ALIGNMENT) = @splat(0),
    Slots: [constants.POOL_SLOTS]PoolSlot = [_]PoolSlot{.{}} ** constants.POOL_SLOTS,
    Reads: [constants.MAX_CALLS]BlockRead = undefined,
    Requested: [constants.MAX_CALLS]usize = @splat(0),
    AllocateCalls: usize = 0,
    FreeCalls: usize = 0,
    ReadCalls: usize = 0,
    FailAllocation: ?usize = null,
    FailFree: ?usize = null,
    DiscoveryHandles: usize = 1,
    FailLBA: ?u64 = null,
    Broken: bool = false,
};
