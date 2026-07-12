//! FAT32 Directory Entry Markers

pub const ENTRY_FREE: u8 = 0xE5;
pub const ENTRY_END: u8 = 0x00;
pub const ENTRY_KANJI_LEAD: u8 = 0x05;

pub const LFN_SEQUENCE_MASK: u8 = 0x1F;
pub const LFN_LAST_ENTRY: u8 = 0x40;
pub const LFN_CHARS_PER_ENTRY: usize = 13;
