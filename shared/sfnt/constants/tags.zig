//! SFNT Table Tags

pub const VERSION_TRUETYPE: u32 = 0x00010000;
pub const VERSION_TRUE: u32 = 0x74727565;
pub const VERSION_OPENTYPE: u32 = 0x4F54544F;
pub const VERSION_COLLECTION: u32 = 0x74746366;

pub const HEAD: u32 = 0x68656164;
pub const MAXP: u32 = 0x6D617870;
pub const HHEA: u32 = 0x68686561;
pub const HMTX: u32 = 0x686D7478;
pub const LOCA: u32 = 0x6C6F6361;
pub const GLYF: u32 = 0x676C7966;
pub const CMAP: u32 = 0x636D6170;
