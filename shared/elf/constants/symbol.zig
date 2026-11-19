//! Native ELF Dynamic Symbol Fields

pub const BINDING_SHIFT = 4;
pub const TYPE_MASK: u8 = 0xf;
pub const VISIBILITY_MASK: u8 = 3;
pub const BINDING_LOCAL: u8 = 0;
pub const BINDING_GLOBAL: u8 = 1;
pub const VISIBILITY_DEFAULT: u8 = 0;
pub const VISIBILITY_PROTECTED: u8 = 3;
pub const TYPE_OBJECT: u8 = 1;
pub const TYPE_FUNCTION: u8 = 2;
pub const SECTION_UNDEFINED: u16 = 0;
pub const SECTION_RESERVED: u16 = 0xff00;
