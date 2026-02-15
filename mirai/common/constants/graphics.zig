//! Graphics constants

// Terminal colors
pub const COLOR_WHITE: u32 = 0x00FFFFFF;
pub const COLOR_BLACK: u32 = 0x00000000;
pub const COLOR_RED: u32 = 0x00FF0000;
pub const COLOR_GREEN: u32 = 0x0000FF00;
pub const COLOR_BLUE: u32 = 0x000000FF;
pub const COLOR_YELLOW: u32 = 0x00FFFF00;
pub const COLOR_CYAN: u32 = 0x0000FFFF;
pub const COLOR_MAGENTA: u32 = 0x00FF00FF;
pub const COLOR_GRAY: u32 = 0x00808080;

// Terminal defaults
pub const DEFAULT_FG: u32 = COLOR_WHITE;
pub const DEFAULT_BG: u32 = COLOR_BLACK;
pub const DEFAULT_CHAR_WIDTH: u32 = 8;
pub const DEFAULT_CHAR_HEIGHT: u32 = 16;
pub const MAX_TERMINAL_LINES: usize = 100;
pub const TAB_WIDTH: u32 = 4;

// Bit depths
pub const BPP_24: u32 = 24;
pub const BPP_32: u32 = 32;
pub const BYTES_PER_PIXEL_24: u32 = 3;
pub const BYTES_PER_PIXEL_32: u32 = 4;

// PSF font magic numbers
pub const PSF1_MAGIC: u16 = 0x0436;
pub const PSF2_MAGIC: u32 = 0x864ab572;
pub const PSF1_MODE_512: u8 = 0x01;
pub const PSF1_GLYPHS_256: u32 = 256;
pub const PSF1_GLYPHS_512: u32 = 512;

// ASCII printable range
pub const ASCII_PRINTABLE_START: u8 = 32;
pub const ASCII_PRINTABLE_END: u8 = 126;

// Control characters
pub const CHAR_NEWLINE: u8 = '\n';
pub const CHAR_BACKSPACE: u8 = 0x08;
pub const CHAR_TAB: u8 = '\t';
