//! UEFI Boot Device Path Node Layout

pub const LIMIT: usize = 4096;
pub const HEADER_BYTES = 4;
pub const TYPE_OFFSET = 0;
pub const SUBTYPE_OFFSET = 1;
pub const LENGTH_OFFSET = 2;

pub const HARDWARE: u8 = 1;
pub const PCI: u8 = 1;
pub const PCI_BYTES = 6;
pub const MESSAGING: u8 = 3;
pub const SATA: u8 = 18;
pub const SATA_BYTES = 10;
pub const END: u8 = 0x7f;
pub const END_ENTIRE: u8 = 0xff;
