//! PCI configuration constants

// Config register offsets
pub const REG_VENDOR_ID: u8 = 0x00;
pub const REG_DEVICE_ID: u8 = 0x02;
pub const REG_COMMAND: u8 = 0x04;
pub const REG_STATUS: u8 = 0x06;
pub const REG_REVISION: u8 = 0x08;
pub const REG_PROG_IF: u8 = 0x09;
pub const REG_SUBCLASS: u8 = 0x0A;
pub const REG_CLASS_CODE: u8 = 0x0B;
pub const REG_HEADER_TYPE: u8 = 0x0E;
pub const REG_BAR0: u8 = 0x10;
pub const REG_BAR1: u8 = 0x14;
pub const REG_BAR2: u8 = 0x18;
pub const REG_BAR3: u8 = 0x1C;
pub const REG_BAR4: u8 = 0x20;
pub const REG_BAR5: u8 = 0x24;
pub const REG_INTERRUPT_LINE: u8 = 0x3C;
pub const REG_INTERRUPT_PIN: u8 = 0x3D;

// Command register bits
pub const CMD_IO_SPACE: u16 = 0x01;
pub const CMD_MEMORY_SPACE: u16 = 0x02;
pub const CMD_BUS_MASTER: u16 = 0x04;

// Class codes
pub const CLASS_MASS_STORAGE: u8 = 0x01;
pub const SUBCLASS_SATA: u8 = 0x06;

// Header type bits
pub const HEADER_MULTIFUNCTION: u8 = 0x80;

// Invalid vendor
pub const VENDOR_INVALID: u16 = 0xFFFF;

// Config address bits
pub const CONFIG_ENABLE: u32 = 1 << 31;
pub const CONFIG_BUS_SHIFT: u5 = 16;
pub const CONFIG_DEVICE_SHIFT: u5 = 11;
pub const CONFIG_FUNCTION_SHIFT: u5 = 8;
pub const CONFIG_OFFSET_MASK: u8 = 0xFC;
