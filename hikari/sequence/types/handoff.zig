//! Hikari Handoff State

const efi = @import("hikari").efi;

pub const Handoff = struct {
    BootServices: *efi.services.boot.BootServices,
    PhysicalLimit: u64,
    StackPhysical: u64 = 0,
    StackPages: usize = 0,
    ParamsPhysical: u64 = 0,
    ParamsPages: usize = 0,
    MapPhysical: u64 = 0,
    MapPages: usize = 0,
    ExitAttempted: bool = false,
    Exited: bool = false,
};
