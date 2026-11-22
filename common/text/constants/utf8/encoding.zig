//! UTF-8 Encoding Constants

pub const REPLACEMENT: u32 = 0xFFFD;

pub const CONTINUATION_MASK: u8 = 0xC0;
pub const CONTINUATION_MARK: u8 = 0x80;
pub const PAYLOAD_MASK: u8 = 0x3F;
pub const PAYLOAD_BITS: u5 = 6;

pub const ASCII_LIMIT: u32 = 0x80;
pub const TWO_BYTE_LEAD_START: u8 = 0xC2;
pub const TWO_BYTE_LEAD_END: u8 = 0xDF;
pub const THREE_BYTE_LEAD_START: u8 = 0xE0;
pub const THREE_BYTE_LEAD_END: u8 = 0xEF;
pub const FOUR_BYTE_LEAD_START: u8 = 0xF0;
pub const FOUR_BYTE_LEAD_END: u8 = 0xF4;
pub const TWO_BYTE_PAYLOAD_MASK: u8 = 0x1F;
pub const THREE_BYTE_PAYLOAD_MASK: u8 = 0x0F;
pub const FOUR_BYTE_PAYLOAD_MASK: u8 = 0x07;
pub const THREE_BYTE_MINIMUM: u32 = 0x800;
pub const FOUR_BYTE_MINIMUM: u32 = 0x10000;

pub const SURROGATE_START: u32 = 0xD800;
pub const SURROGATE_END: u32 = 0xDFFF;
pub const MAXIMUM: u32 = 0x10FFFF;
