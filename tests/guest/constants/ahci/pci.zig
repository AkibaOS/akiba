//! Q35 Fixture PCI Configuration Values

pub const PCI_ADDRESS: u16 = 0xcf8;
pub const PCI_DATA: u16 = 0xcfc;
pub const ICH9_ADDRESS: u32 = 0x8000fa00;
pub const ICH9_ID: u32 = 0x29228086;
pub const PCI_ID: u32 = 0;
pub const PCI_COMMAND: u32 = 4;
pub const PCI_CLASS: u32 = 8;
pub const PCI_BAR: u32 = 0x24;
pub const AHCI_CLASS: u32 = 0x010601;
pub const REVISION_BITS = 8;
pub const BAR_FLAGS: u32 = 0xf;
pub const MEMORY_ENABLE: u16 = 1 << 1;
pub const BUS_MASTER: u16 = 1 << 2;
