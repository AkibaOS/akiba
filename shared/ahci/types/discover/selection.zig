//! Boot Candidate Callback And Unattached Location

const Address = @import("shared").ahci.types.discover.configuration.Address;
const Controller = @import("shared").ahci.types.discover.controller.Controller;

pub const Location = struct {
    Address: Address,
    Port: u8,
};

pub const Probe = struct {
    Context: *anyopaque,
    Find: *const fn (*anyopaque, Controller) anyerror!?u8,
};
