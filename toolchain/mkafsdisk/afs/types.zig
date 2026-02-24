//! AFS Types for mkafsdisk
//! Must match hikari/fs/afs/types.zig

const constants = @import("constants.zig");

pub const VolumeHeader = extern struct {
    signature: u64 = constants.signature,
    version: u16 = constants.version,
    attributes: u32 = 0,
    last_bind_timestamp: u64 = 0,
    last_check_timestamp: u64 = 0,
    creation_timestamp: u64 = 0,
    modification_timestamp: u64 = 0,
    backup_timestamp: u64 = 0,
    checked_timestamp: u64 = 0,
    unit_count: u32 = 0,
    stack_count: u32 = 0,
    cell_size: u32 = constants.default_cell_size,
    total_cells: u32 = 0,
    free_cells: u32 = 0,
    next_node_id: u32 = constants.first_user_node_id,
    write_count: u32 = 1,
    encoding_bitmap: u64 = 0,
    allocation_map_size: u32 = 0,
    allocation_map_clump: u32 = 0,
    index_node_size: u32 = constants.default_cell_size,
    index_total_nodes: u32 = 0,
    index_free_nodes: u32 = 0,
    index_clump_size: u32 = 0,
    index_root_node: u32 = 1,
    index_first_leaf: u32 = 1,
    index_last_leaf: u32 = 1,
    index_depth: u16 = 1,
    index_record_count: u32 = 0,
    span_overflow_node_size: u32 = constants.default_cell_size,
    span_overflow_total_nodes: u32 = 0,
    span_overflow_free_nodes: u32 = 0,
    span_overflow_clump_size: u32 = 0,
    span_overflow_root_node: u32 = 0,
    span_overflow_first_leaf: u32 = 0,
    span_overflow_last_leaf: u32 = 0,
    span_overflow_depth: u16 = 0,
    span_overflow_record_count: u32 = 0,
    attributes_node_size: u32 = constants.default_cell_size,
    attributes_total_nodes: u32 = 0,
    attributes_free_nodes: u32 = 0,
    attributes_clump_size: u32 = 0,
    attributes_root_node: u32 = 0,
    attributes_first_leaf: u32 = 0,
    attributes_last_leaf: u32 = 0,
    attributes_depth: u16 = 0,
    attributes_record_count: u32 = 0,
    allocation_map_span: SpanDescriptor = .{},
    index_span: SpanDescriptor = .{},
    span_overflow_span: SpanDescriptor = .{},
    attributes_span: SpanDescriptor = .{},
    startup_span: SpanDescriptor = .{},
    journal_info_cell: u64 = constants.journal_info_cell,
    journal_info_size: u32 = constants.journal_header_size,
    compression_type: u32 = constants.compression_none,
    encryption_type: u32 = constants.encryption_none,
    reserved: [64]u8 = [_]u8{0} ** 64,
};

pub const SpanDescriptor = extern struct {
    start_cell: u64 = 0,
    cell_count: u64 = 0,
};

pub const ChannelInfo = extern struct {
    logical_size: u64 = 0,
    physical_size: u64 = 0,
    clump_size: u32 = 0,
    total_cells: u32 = 0,
    spans: [constants.span_inline_count]SpanDescriptor = [_]SpanDescriptor{.{}} ** constants.span_inline_count,
};

pub const BTreeNodeDescriptor = extern struct {
    forward_link: u32 = 0,
    backward_link: u32 = 0,
    node_type: i8 = constants.btree_node_type_leaf,
    height: u8 = 0,
    record_count: u16 = 0,
    reserved: u16 = 0,
};

pub const BTreeHeaderRecord = extern struct {
    depth: u16 = 1,
    root_node: u32 = 1,
    leaf_record_count: u32 = 0,
    first_leaf_node: u32 = 1,
    last_leaf_node: u32 = 1,
    node_size: u16 = 0,
    max_key_length: u16 = 0,
    total_nodes: u32 = 0,
    free_nodes: u32 = 0,
    reserved1: u16 = 0,
    clump_size: u32 = 0,
    btree_type: u8 = 0,
    key_compare_type: u8 = 0,
    attributes: u32 = 0,
    reserved2: [64]u8 = [_]u8{0} ** 64,
};

pub const IndexKey = extern struct {
    key_length: u16 = 0,
    parent_node_id: u32 = 0,
    identity: [256]u16 = [_]u16{0} ** 256,
};

pub const StackRecord = extern struct {
    record_type: u16 = constants.index_record_type_stack,
    flags: u16 = 0,
    valence: u32 = 0,
    node_id: u32 = 0,
    creation_timestamp: u64 = 0,
    modification_timestamp: u64 = 0,
    attribute_modification_timestamp: u64 = 0,
    access_timestamp: u64 = 0,
    backup_timestamp: u64 = 0,
    permissions: Permissions = .{},
    special: [16]u8 = [_]u8{0} ** 16,
    text_encoding: u32 = 0,
    reserved: u32 = 0,
};

pub const UnitRecord = extern struct {
    record_type: u16 = constants.index_record_type_unit,
    flags: u16 = 0,
    reserved1: u32 = 0,
    node_id: u32 = 0,
    creation_timestamp: u64 = 0,
    modification_timestamp: u64 = 0,
    attribute_modification_timestamp: u64 = 0,
    access_timestamp: u64 = 0,
    backup_timestamp: u64 = 0,
    permissions: Permissions = .{},
    special: [16]u8 = [_]u8{0} ** 16,
    text_encoding: u32 = 0,
    reserved2: u32 = 0,
    data_channel: ChannelInfo = .{},
    resource_channel: ChannelInfo = .{},
};

pub const ThreadRecord = extern struct {
    record_type: u16 = constants.index_record_type_stack_thread,
    reserved: u16 = 0,
    parent_node_id: u32 = 0,
    identity_length: u16 = 0,
    identity: [256]u16 = [_]u16{0} ** 256,
};

pub const Permissions = extern struct {
    owner_id: u32 = 0,
    group_id: u32 = 0,
    admin_flags: u8 = 0,
    owner_flags: u8 = 0,
    mode: u16 = 0o755,
    inode_or_link: u32 = 0,
};

pub const JournalInfoCell = extern struct {
    flags: u32 = 0,
    device_signature: [32]u32 = [_]u32{0} ** 32,
    offset: u64 = 0,
    size: u64 = 0,
    reserved: [128]u8 = [_]u8{0} ** 128,
};

pub const JournalHeader = extern struct {
    magic: u32 = constants.journal_signature,
    endian: u32 = 0x12345678,
    start: u64 = 0,
    end: u64 = 0,
    size: u64 = 0,
    cell_size: u32 = constants.default_cell_size,
    checksum_type: u32 = 0,
    checksum: u32 = 0,
    sequence: u64 = 0,
};
