//! Glyph Outline Flags

pub const ON_CURVE_POINT: u8 = 0x01;
pub const X_SHORT_VECTOR: u8 = 0x02;
pub const Y_SHORT_VECTOR: u8 = 0x04;
pub const REPEAT_FLAG: u8 = 0x08;
pub const X_SAME_OR_POSITIVE: u8 = 0x10;
pub const Y_SAME_OR_POSITIVE: u8 = 0x20;

pub const ARGS_ARE_WORDS: u16 = 0x0001;
pub const ARGS_ARE_XY_VALUES: u16 = 0x0002;
pub const HAS_SCALE: u16 = 0x0008;
pub const MORE_COMPONENTS: u16 = 0x0020;
pub const HAS_X_AND_Y_SCALE: u16 = 0x0040;
pub const HAS_TWO_BY_TWO: u16 = 0x0080;
pub const HAS_INSTRUCTIONS: u16 = 0x0100;

pub const TRANSFORM_FRACTION_BITS: u5 = 14;
pub const TRANSFORM_ONE: i32 = 1 << TRANSFORM_FRACTION_BITS;
