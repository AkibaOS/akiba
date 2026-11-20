//! Caller-Owned Hikari Handoff Allocations

const efi = @import("hikari").efi;

const Allocation = efi.types.pages.claims.Allocation;

pub const Handoff = struct {
    BootServices: *efi.types.services.boot.BootServices,
    PhysicalLimit: u64,
    Stack: ?Allocation = null,
    Parameters: ?Allocation = null,
    Map: ?Allocation = null,
    Replacement: ?Allocation = null,
    Closing: bool = false,
    UntrustedAllocation: bool = false,
    ExitAttempted: bool = false,
    Exited: bool = false,
};
