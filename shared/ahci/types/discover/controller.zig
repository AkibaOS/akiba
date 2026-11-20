//! Checked Firmware Configured AHCI Aperture

const Address = @import("shared").ahci.types.discover.configuration.Address;

pub const Controller = struct {
    Address: Address,
    Bar: u32,
    Command: u16,
};
