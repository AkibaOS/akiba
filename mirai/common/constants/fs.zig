//! Filesystem constants

// Sector and cluster
pub const SECTOR_SIZE: usize = 512;
pub const SECTOR_ALIGN: u8 = 16;

// AFS signatures
pub const AFS_SIGNATURE = "AKIBAFS!";
pub const AFS_BOOT_SIG: u16 = 0xAA55;

// AFS entry types
pub const ENTRY_TYPE_END: u8 = 0x00;
pub const ENTRY_TYPE_UNIT: u8 = 0x01;
pub const ENTRY_TYPE_STACK: u8 = 0x02;

// AFS permissions
pub const PERM_OWNER: u8 = 1;
pub const PERM_WORLD: u8 = 2;
pub const PERM_READ_ONLY: u8 = 3;

// AFS cluster markers
pub const CLUSTER_FREE: u32 = 0x00000000;
pub const CLUSTER_END: u32 = 0xFFFFFFFF;
pub const CLUSTER_MIN: u32 = 2;

// AFS limits
pub const MAX_IDENTITY_LEN: usize = 255;
pub const MAX_OWNER_NAME_LEN: usize = 64;
pub const MAX_LOCATION_LENGTH: usize = 256;
pub const PARENT_CACHE_SIZE: usize = 256;

// GPT
pub const GPT_SIGNATURE = "EFI PART";
pub const GPT_HEADER_SECTOR: u64 = 1;
pub const GPT_PARTITION_ENTRIES_MAX: usize = 4;
pub const GPT_ENTRY_SIZE: usize = 128;
pub const GPT_HEADER_PARTITION_LBA_OFFSET: usize = 72;
pub const GPT_ENTRY_TYPE_GUID_SIZE: usize = 16;
pub const GPT_ENTRY_START_LBA_OFFSET: usize = 32;
pub const GPT_ENTRY_END_LBA_OFFSET: usize = 40;

// AFS partition GUID
pub const AFS_PARTITION_GUID = [_]u8{
    0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6, 0x07, 0x18,
    0x29, 0x3A, 0x4B, 0x5C, 0x6D, 0x7E, 0x8F, 0x90,
};
