//! Firmware Handoff Regression Types

const base = @import("hikari").efi.types.base;
const constants = @import("tests").constants.firmware;
const services = @import("hikari").efi.types.services;

pub const MapReply = struct {
    Status: base.Status,
    Size: usize = constants.MAP_BYTES,
    Key: usize = constants.FIRST_KEY,
    DescriptorSize: usize = constants.DESCRIPTOR_BYTES,
    DescriptorVersion: u32 = constants.DESCRIPTOR_VERSION,
};

pub const PageAllocation = struct {
    Address: u64 = 0,
    Pages: usize = 0,
};

pub const Fixture = struct {
    Real: *services.boot.BootServices,
    ImageHandle: base.Handle,
    MapScript: []const MapReply = &.{},
    ExitScript: []const base.Status = &.{},
    Ledger: [constants.LEDGER_CAPACITY]PageAllocation = [_]PageAllocation{.{}} ** constants.LEDGER_CAPACITY,
    Created: [constants.TRACE_CAPACITY]PageAllocation = [_]PageAllocation{.{}} ** constants.TRACE_CAPACITY,
    Freed: [constants.TRACE_CAPACITY]PageAllocation = [_]PageAllocation{.{}} ** constants.TRACE_CAPACITY,
    MapCapacities: [constants.SCRIPT_CAPACITY]usize = [_]usize{0} ** constants.SCRIPT_CAPACITY,
    ExitKeys: [constants.SCRIPT_CAPACITY]usize = [_]usize{0} ** constants.SCRIPT_CAPACITY,
    AllocateCalls: usize = 0,
    CreatedCount: usize = 0,
    FreeCalls: usize = 0,
    MapCalls: usize = 0,
    ExitCalls: usize = 0,
    FailAllocateCall: ?usize = null,
    FailFreeCall: ?usize = null,
    ScriptMismatch: bool = false,
};
