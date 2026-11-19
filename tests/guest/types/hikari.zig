//! Hikari Guest Regression Types

const constants = @import("tests").constants.hikari;
const memory = @import("hikari").efi.types.memory;

pub const ELFBytes = [constants.ELF_BYTES]u8;

pub const PoolState = struct {
    Storage: [constants.POOL_BYTES]u8 align(constants.POOL_ALIGNMENT) = [_]u8{constants.POOL_GUARD} ** constants.POOL_BYTES,
    AllocateCalls: usize = 0,
    FreeCalls: usize = 0,
    RequestedBytes: usize = 0,
    PoolType: ?memory.MemoryType = null,
    FreedAddress: ?usize = null,
    FailAllocation: bool = false,
    FailFree: bool = false,
    OmitOutput: bool = false,
    OverrideAddress: ?usize = null,
};
