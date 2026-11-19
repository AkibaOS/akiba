//! Rendering Regression Text

pub const EMPTY = "";
pub const LETTER = "A";
pub const SECOND_LETTER = "B";
pub const PAIR = "AB";
pub const REPEATED = "AAAA";
pub const MISSING = "??";
pub const MULTIBYTE = "A¢€🙂";
pub const INVALID_UTF8 = "\xFFA\xE2\x82";
pub const CONSOLE_CONTROLS = "A\rB\x08\t";
pub const LONG_MESSAGE = "A" ** 80;
pub const REAL_FACE = "Aア";
