//! AFS Flags

pub const unit_locked: u16 = 0x0001;
pub const unit_has_thread: u16 = 0x0002;
pub const unit_has_alias: u16 = 0x0004;
pub const unit_has_security: u16 = 0x0008;
pub const unit_has_twins: u16 = 0x0010;
pub const unit_has_resource_channel: u16 = 0x0020;

pub const channel_data: u8 = 0x00;
pub const channel_resource: u8 = 0xFF;

pub const compression_none: u32 = 0;
pub const compression_zlib: u32 = 1;
pub const compression_lz4: u32 = 2;
pub const compression_zstd: u32 = 3;

pub const encryption_none: u32 = 0;
pub const encryption_aes_128_xts: u32 = 1;
pub const encryption_aes_256_xts: u32 = 2;

pub const journal_on_other_device: u32 = 0x00000001;
pub const journal_needs_init: u32 = 0x00000002;
