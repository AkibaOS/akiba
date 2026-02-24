//! AFS Constants for mkafsdisk
//! Must match hikari/fs/afs/constants.zig

pub const signature: u64 = 0x2153464142494B41; // "AKIBAFS!"
pub const version: u16 = 0x0001;

pub const volume_header_cell: u64 = 0;
pub const volume_header_size: u32 = 512;
pub const alternate_volume_header_offset: u64 = 1024;

pub const default_cell_size: u32 = 4096;
pub const minimum_cell_size: u32 = 512;
pub const maximum_cell_size: u32 = 65536;

pub const max_identity_length: usize = 1024;

pub const special_node_id_origin: u32 = 1;
pub const special_node_id_origin_stack: u32 = 2;
pub const special_node_id_span_overflow: u32 = 3;
pub const special_node_id_index: u32 = 4;
pub const special_node_id_attributes: u32 = 5;
pub const special_node_id_allocation_map: u32 = 6;
pub const special_node_id_startup: u32 = 7;
pub const special_node_id_repair: u32 = 8;
pub const first_user_node_id: u32 = 16;

pub const index_record_type_stack: u16 = 0x0001;
pub const index_record_type_unit: u16 = 0x0002;
pub const index_record_type_stack_thread: u16 = 0x0003;
pub const index_record_type_unit_thread: u16 = 0x0004;

pub const btree_node_type_leaf: i8 = -1;
pub const btree_node_type_index: i8 = 0;
pub const btree_node_type_header: i8 = 1;
pub const btree_node_type_map: i8 = 2;

pub const btree_header_node_number: u32 = 0;

pub const channel_data: u8 = 0x00;
pub const channel_resource: u8 = 0xFF;

pub const unit_flag_locked: u16 = 0x0001;
pub const unit_flag_has_thread: u16 = 0x0002;
pub const unit_flag_has_alias: u16 = 0x0004;
pub const unit_flag_has_security: u16 = 0x0008;
pub const unit_flag_has_twins: u16 = 0x0010;
pub const unit_flag_has_resource_channel: u16 = 0x0020;

pub const compression_none: u32 = 0;
pub const compression_zlib: u32 = 1;
pub const compression_lz4: u32 = 2;
pub const compression_zstd: u32 = 3;

pub const encryption_none: u32 = 0;
pub const encryption_aes_128_xts: u32 = 1;
pub const encryption_aes_256_xts: u32 = 2;

pub const attribute_inline_data_max: u32 = 3802;

pub const journal_signature: u32 = 0x4A4E524C; // "JNRL"
pub const journal_header_size: u32 = 512;
pub const journal_info_cell: u64 = 2;

pub const journal_info_on_other_device: u32 = 0x00000001;
pub const journal_info_needs_init: u32 = 0x00000002;

pub const span_inline_count: usize = 8;

// AFS partition type GUID: 414B4942-4146-5300-0000-000000000001
pub const partition_type_guid = [16]u8{
    0x42, 0x49, 0x4B, 0x41, // time_low (little endian)
    0x46, 0x41, // time_mid
    0x00, 0x53, // time_high_and_version
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // clock_seq_and_node
};
