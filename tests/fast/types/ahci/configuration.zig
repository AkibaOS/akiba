//! PCI Functions And Candidate Read Trace For Host Regressions

const values = @import("tests").fast.constants.ahci.configuration;

pub const Device = struct {
    Key: u16,
    Class: u32 = values.AHCI_CLASS,
    Header: u32 = 0,
    Command: u16 = values.MEMORY_ENABLED,
    Bar: u32 = values.BAR,
    Port: ?u8 = null,
    Fails: bool = false,
};

pub const Trace = struct {
    Devices: []const Device,
    Checked: usize = 0,
    ReadGhost: bool = false,
};
