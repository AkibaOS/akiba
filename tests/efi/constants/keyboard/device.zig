//! EFI PS/2 Device Path And Escape Code

pub const DEVICE_PATH_LIMIT: usize = 1024;
pub const DEVICE_PATH_HEADER: usize = 4;
pub const END_DEVICE_PATH: u8 = 0x7f;
pub const END_ENTIRE_PATH: u8 = 0xff;
pub const ACPI_DEVICE_PATH: u8 = 0x02;
pub const ACPI_HID_SUBTYPE: u8 = 0x01;
pub const ACPI_HID_BYTES: usize = 12;
pub const PS2_KEYBOARD_HID: u32 = 0x030341d0;
pub const ESCAPE_SCAN: u16 = 0x17;
