//! Diagnostic Q35 LPC Timer Registers

pub const PCI_ADDRESS: u16 = 0xcf8;
pub const PCI_DATA: u16 = 0xcfc;
pub const Q35_LPC_ADDRESS: u32 = 0x8000_f800;
pub const Q35_LPC_ID: u32 = 0x2918_8086;
pub const LPC_ID_REGISTER: u32 = 0;
pub const LPC_BASE_REGISTER: u32 = 0x40;
pub const LPC_CONTROL_REGISTER: u32 = 0x44;
pub const ACPI_ENABLE: u32 = 0x80;
pub const BASE_MASK: u32 = 0xff80;
pub const TIMER_OFFSET: u16 = 8;
