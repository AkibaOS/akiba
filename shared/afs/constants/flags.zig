//! AFS Flags

pub const UNIT_LOCKED: u16 = 0x0001;
pub const UNIT_HAS_THREAD: u16 = 0x0002;
pub const UNIT_HAS_ALIAS: u16 = 0x0004;
pub const UNIT_HAS_SECURITY: u16 = 0x0008;
pub const UNIT_HAS_TWINS: u16 = 0x0010;
pub const UNIT_HAS_RESOURCE_CHANNEL: u16 = 0x0020;

pub const CHANNEL_DATA: u8 = 0x00;
pub const CHANNEL_RESOURCE: u8 = 0xFF;

pub const COMPRESSION_NONE: u32 = 0;
pub const COMPRESSION_ZLIB: u32 = 1;
pub const COMPRESSION_LZ4: u32 = 2;
pub const COMPRESSION_ZSTD: u32 = 3;

pub const ENCRYPTION_NONE: u32 = 0;
pub const ENCRYPTION_AES_128_XTS: u32 = 1;
pub const ENCRYPTION_AES_256_XTS: u32 = 2;

pub const JOURNAL_ON_OTHER_DEVICE: u32 = 0x00000001;
pub const JOURNAL_NEEDS_INIT: u32 = 0x00000002;
