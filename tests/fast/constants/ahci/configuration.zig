//! Independent PCI Configuration Fixture Values

pub const IDENTIFIER_OFFSET = 0;
pub const COMMAND_OFFSET = 4;
pub const CLASS_OFFSET = 8;
pub const HEADER_OFFSET = 12;
pub const BAR_OFFSET = 36;
pub const ABSENT: u32 = 0xffff_ffff;
pub const IDENTIFIER: u32 = 0x8487_1234;
pub const AHCI_CLASS: u32 = 0x0106_01a7;
pub const BRIDGE_CLASS: u32 = 0x0604_0000;
pub const LEGACY_IDE_CLASS: u32 = 0x0101_8f00;
pub const BRIDGE_HEADER: u32 = 0x0081_0000;
pub const WRONG_HEADER: u32 = 0x0001_0000;
pub const MEMORY_ENABLED: u16 = 2;
pub const BAR: u32 = 0xfebf_0000;
pub const IO_BAR: u32 = BAR | 1;
pub const UNALIGNED_BAR: u32 = BAR | 0x200;
pub const FIRST_TARGET: u16 = 0x031c;
pub const FIRST_SLOT: u16 = 0x0318;
pub const REMOTE_TARGET: u16 = 0xe1c8;
pub const SINGLE_SLOT: u16 = 0x0030;
pub const GHOST_FUNCTION: u16 = 0x0031;
pub const TARGET_PORT: u8 = 3;
