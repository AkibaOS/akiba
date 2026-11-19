//! Firmware ELF Loading Regression Types

const constants = @import("tests").efi.constants.firmware.loading;
const memory = @import("hikari").efi.types.memory;
const services = @import("hikari").efi.types.services;

pub const AllocationRequest = struct {
    AllocateType: memory.AllocateType,
    MemoryType: memory.MemoryType,
    Pages: usize,
    Address: u64,
};

pub const PageAllocation = struct {
    Address: u64,
    Pages: usize,
};

pub const SegmentExpectation = struct {
    PhysicalOffset: u64,
    VirtualAddress: u64,
    MemorySize: u64,
    Flags: u32,
};

pub const Fixture = struct {
    Real: *services.boot.BootServices,
    Requests: [constants.REQUEST_CAPACITY]AllocationRequest = undefined,
    Owned: ?PageAllocation = null,
    Created: ?PageAllocation = null,
    Freed: ?PageAllocation = null,
    AllocateCalls: usize = 0,
    FreeCalls: usize = 0,
    RejectFallback: bool = false,
    WrongFixedAddress: bool = false,
    Dirtied: bool = false,
    ProtocolMismatch: bool = false,
};
