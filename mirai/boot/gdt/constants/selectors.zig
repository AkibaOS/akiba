//! GDT Selector Constants

pub const null_selector: u16 = 0x00;
pub const kernel_code_selector: u16 = 0x08;
pub const kernel_data_selector: u16 = 0x10;
pub const user_code_selector: u16 = 0x18;
pub const user_data_selector: u16 = 0x20;
pub const tss_selector: u16 = 0x28;

pub const kernel_code_index: u16 = 1;
pub const kernel_data_index: u16 = 2;
pub const user_code_index: u16 = 3;
pub const user_data_index: u16 = 4;
pub const tss_index: u16 = 5;

pub const ring_0: u8 = 0;
pub const ring_3: u8 = 3;

pub fn selector_with_rpl(selector: u16, rpl: u8) u16 {
    return (selector & 0xFFF8) | @as(u16, rpl & 0x03);
}
