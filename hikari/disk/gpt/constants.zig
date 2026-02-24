//! Hikari GPT Constants

pub const signature: u64 = 0x5452415020494645; // "EFI PART"
pub const revision_1_0: u32 = 0x00010000;

pub const header_size_minimum: u32 = 92;
pub const header_lba: u64 = 1;

pub const partition_entry_size_minimum: u32 = 128;
pub const partition_entries_start_lba: u64 = 2;
pub const partition_entries_count_maximum: u32 = 128;

pub const partition_identity_length: usize = 36;

pub const protective_mbr_signature: u16 = 0xAA55;
pub const protective_mbr_partition_type: u8 = 0xEE;
