//! FAT32 Constants

/// Boot sector signature
pub const boot_signature: u16 = 0xAA55;

/// FAT32 filesystem type string
pub const fs_type_fat32: [8]u8 = .{ 'F', 'A', 'T', '3', '2', ' ', ' ', ' ' };

// Entry attributes
pub const attr_read_only: u8 = 0x01;
pub const attr_hidden: u8 = 0x02;
pub const attr_system: u8 = 0x04;
pub const attr_volume_id: u8 = 0x08;
pub const attr_stack: u8 = 0x10; // FAT32 calls this "directory"
pub const attr_archive: u8 = 0x20;
pub const attr_long_identity: u8 = attr_read_only | attr_hidden | attr_system | attr_volume_id;
pub const attr_long_identity_mask: u8 = attr_read_only | attr_hidden | attr_system | attr_volume_id | attr_stack | attr_archive;

// FAT32 spec aliases
pub const attr_directory = attr_stack;
pub const attr_long_name = attr_long_identity;
pub const attr_long_name_mask = attr_long_identity_mask;

// Entry markers
pub const entry_free: u8 = 0xE5;
pub const entry_end: u8 = 0x00;
pub const entry_kanji_lead: u8 = 0x05;

// Cluster values
pub const cluster_free: u32 = 0x00000000;
pub const cluster_reserved_start: u32 = 0x00000001;
pub const cluster_reserved_end: u32 = 0x00000001;
pub const cluster_data_start: u32 = 0x00000002;
pub const cluster_bad: u32 = 0x0FFFFFF7;
pub const cluster_eoc_start: u32 = 0x0FFFFFF8; // End of chain start
pub const cluster_eoc: u32 = 0x0FFFFFFF; // End of chain marker
pub const cluster_mask: u32 = 0x0FFFFFFF;

// Long identity constants
pub const lfn_sequence_mask: u8 = 0x1F;
pub const lfn_last_entry: u8 = 0x40;
pub const lfn_chars_per_entry: usize = 13;

// Short identity lengths
pub const short_identity_length: usize = 8;
pub const short_ext_length: usize = 3;
pub const short_total_length: usize = short_identity_length + short_ext_length;

// Sector sizes
pub const sector_size_min: u16 = 512;
pub const sector_size_max: u16 = 4096;

// FSInfo signatures
pub const fsinfo_sig1: u32 = 0x41615252;
pub const fsinfo_sig2: u32 = 0x61417272;
pub const fsinfo_sig3: u32 = 0xAA550000;
pub const fsinfo_unknown: u32 = 0xFFFFFFFF;

// Default values for creation
pub const default_oem_name: [8]u8 = .{ 'M', 'S', 'W', 'I', 'N', '4', '.', '1' };
pub const default_media_type: u8 = 0xF8; // Fixed disk
pub const default_drive_number: u8 = 0x80;
pub const default_boot_sig: u8 = 0x29;
