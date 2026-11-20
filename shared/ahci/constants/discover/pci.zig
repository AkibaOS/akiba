//! AHCI Configuration Fields Within PCI Segment Zero

pub const ADDRESS_COUNT: u32 = 1 << @bitSizeOf(u16);
pub const FUNCTIONS_PER_SLOT: u32 = 1 << @bitSizeOf(u3);
pub const IDENTIFIER_OFFSET: u8 = 0;
pub const COMMAND_OFFSET: u8 = 4;
pub const CLASS_OFFSET: u8 = 8;
pub const HEADER_OFFSET: u8 = 12;
pub const BAR_OFFSET: u8 = 0x24;
pub const ABSENT_VENDOR: u16 = 0xffff;
pub const HEADER_SHIFT = 16;
pub const MULTIFUNCTION: u8 = 0x80;
pub const HEADER_KIND: u8 = 0x7f;
pub const TYPE_ZERO: u8 = 0;
pub const CLASS_SHIFT = 8;
pub const AHCI_CLASS: u32 = 0x010601;
pub const MEMORY_ENABLE: u16 = 1 << 1;
pub const BUS_MASTER: u16 = 1 << 2;
