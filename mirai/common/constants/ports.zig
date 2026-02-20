//! I/O port addresses

// Serial (COM1)
pub const COM1: u16 = 0x3F8;
pub const COM1_DATA: u16 = COM1;
pub const COM1_INT_ENABLE: u16 = COM1 + 1;
pub const COM1_FIFO_CTRL: u16 = COM1 + 2;
pub const COM1_LINE_CTRL: u16 = COM1 + 3;
pub const COM1_MODEM_CTRL: u16 = COM1 + 4;
pub const COM1_LINE_STATUS: u16 = COM1 + 5;

// PS/2 Keyboard
pub const KEYBOARD_DATA: u16 = 0x60;
pub const KEYBOARD_STATUS: u16 = 0x64;

// PIC
pub const PIC1_CMD: u16 = 0x20;
pub const PIC1_DATA: u16 = 0x21;
pub const PIC2_CMD: u16 = 0xA0;
pub const PIC2_DATA: u16 = 0xA1;
pub const PIC_EOI: u8 = 0x20;

// PCI
pub const PCI_CONFIG_ADDRESS: u16 = 0xCF8;
pub const PCI_CONFIG_DATA: u16 = 0xCFC;

// VGA
pub const VGA_BUFFER_ADDR: usize = 0xB8000;

// CMOS/RTC
pub const CMOS_ADDRESS: u16 = 0x70;
pub const CMOS_DATA: u16 = 0x71;
