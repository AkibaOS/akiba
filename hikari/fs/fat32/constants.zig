//! Hikari FAT32 Constants

pub const boot_signature: u16 = 0xAA55;
pub const fs_type_fat32: [8]u8 = .{ 'F', 'A', 'T', '3', '2', ' ', ' ', ' ' };

pub const attribute_read_only: u8 = 0x01;
pub const attribute_hidden: u8 = 0x02;
pub const attribute_system: u8 = 0x04;
pub const attribute_volume_id: u8 = 0x08;
pub const attribute_stack: u8 = 0x10;
pub const attribute_archive: u8 = 0x20;
pub const attribute_long_identity: u8 = attribute_read_only | attribute_hidden | attribute_system | attribute_volume_id;
pub const attribute_long_identity_mask: u8 = attribute_read_only | attribute_hidden | attribute_system | attribute_volume_id | attribute_stack | attribute_archive;

pub const entry_free: u8 = 0xE5;
pub const entry_end: u8 = 0x00;
pub const entry_kanji_lead: u8 = 0x05;

pub const cluster_free: u32 = 0x00000000;
pub const cluster_reserved_start: u32 = 0x00000001;
pub const cluster_reserved_end: u32 = 0x00000001;
pub const cluster_data_start: u32 = 0x00000002;
pub const cluster_bad: u32 = 0x0FFFFFF7;
pub const cluster_end_of_chain_start: u32 = 0x0FFFFFF8;
pub const cluster_end_of_chain: u32 = 0x0FFFFFFF;
pub const cluster_mask: u32 = 0x0FFFFFFF;

pub const long_identity_sequence_mask: u8 = 0x1F;
pub const long_identity_last_entry: u8 = 0x40;
pub const long_identity_chars_per_entry: usize = 13;

pub const short_identity_length: usize = 8;
pub const short_extension_length: usize = 3;
pub const short_identity_total_length: usize = short_identity_length + short_extension_length;

pub const sector_size_minimum: u16 = 512;
pub const sector_size_maximum: u16 = 4096;

pub const fs_info_signature_1: u32 = 0x41615252;
pub const fs_info_signature_2: u32 = 0x61417272;
pub const fs_info_signature_3: u32 = 0xAA550000;
pub const fs_info_unknown_free_count: u32 = 0xFFFFFFFF;
pub const fs_info_unknown_next_free: u32 = 0xFFFFFFFF;
