//! Hikari AFS Types

const constants = @import("constants.zig");

pub const VolumeHeader = extern struct {
    signature: u64,
    version: u16,
    attributes: u32,
    last_bind_timestamp: u64,
    last_check_timestamp: u64,
    creation_timestamp: u64,
    modification_timestamp: u64,
    backup_timestamp: u64,
    checked_timestamp: u64,
    unit_count: u32,
    stack_count: u32,
    cell_size: u32,
    total_cells: u32,
    free_cells: u32,
    next_node_id: u32,
    write_count: u32,
    encoding_bitmap: u64,
    allocation_map_size: u32,
    allocation_map_clump: u32,
    index_node_size: u32,
    index_total_nodes: u32,
    index_free_nodes: u32,
    index_clump_size: u32,
    index_root_node: u32,
    index_first_leaf: u32,
    index_last_leaf: u32,
    index_depth: u16,
    index_record_count: u32,
    span_overflow_node_size: u32,
    span_overflow_total_nodes: u32,
    span_overflow_free_nodes: u32,
    span_overflow_clump_size: u32,
    span_overflow_root_node: u32,
    span_overflow_first_leaf: u32,
    span_overflow_last_leaf: u32,
    span_overflow_depth: u16,
    span_overflow_record_count: u32,
    attributes_node_size: u32,
    attributes_total_nodes: u32,
    attributes_free_nodes: u32,
    attributes_clump_size: u32,
    attributes_root_node: u32,
    attributes_first_leaf: u32,
    attributes_last_leaf: u32,
    attributes_depth: u16,
    attributes_record_count: u32,
    allocation_map_span: SpanDescriptor,
    index_span: SpanDescriptor,
    span_overflow_span: SpanDescriptor,
    attributes_span: SpanDescriptor,
    startup_span: SpanDescriptor,
    journal_info_cell: u64,
    journal_info_size: u32,
    compression_type: u32,
    encryption_type: u32,
    reserved: [64]u8,

    pub fn is_valid(self: *const VolumeHeader) bool {
        if (self.signature != constants.signature) {
            return false;
        }
        if (self.version != constants.version) {
            return false;
        }
        if (self.cell_size < constants.minimum_cell_size or
            self.cell_size > constants.maximum_cell_size)
        {
            return false;
        }
        return true;
    }
};

pub const SpanDescriptor = extern struct {
    start_cell: u64,
    cell_count: u64,

    pub fn is_empty(self: *const SpanDescriptor) bool {
        return self.cell_count == 0;
    }

    pub fn end_cell(self: *const SpanDescriptor) u64 {
        return self.start_cell + self.cell_count;
    }

    pub fn contains(self: *const SpanDescriptor, cell: u64) bool {
        return cell >= self.start_cell and cell < self.end_cell();
    }

    pub fn byte_size(self: *const SpanDescriptor, cell_size: u32) u64 {
        return self.cell_count * cell_size;
    }
};

pub const ChannelInfo = extern struct {
    logical_size: u64,
    physical_size: u64,
    clump_size: u32,
    total_cells: u32,
    spans: [constants.span_inline_count]SpanDescriptor,

    pub fn get_span(self: *const ChannelInfo, index: usize) ?*const SpanDescriptor {
        if (index >= constants.span_inline_count) {
            return null;
        }
        if (self.spans[index].is_empty()) {
            return null;
        }
        return &self.spans[index];
    }
};

pub const BTreeNodeDescriptor = extern struct {
    forward_link: u32,
    backward_link: u32,
    node_type: i8,
    height: u8,
    record_count: u16,
    reserved: u16,

    pub fn is_leaf(self: *const BTreeNodeDescriptor) bool {
        return self.node_type == constants.btree_node_type_leaf;
    }

    pub fn is_index(self: *const BTreeNodeDescriptor) bool {
        return self.node_type == constants.btree_node_type_index;
    }

    pub fn is_header(self: *const BTreeNodeDescriptor) bool {
        return self.node_type == constants.btree_node_type_header;
    }

    pub fn is_map(self: *const BTreeNodeDescriptor) bool {
        return self.node_type == constants.btree_node_type_map;
    }
};

pub const BTreeHeaderRecord = extern struct {
    depth: u16,
    root_node: u32,
    leaf_record_count: u32,
    first_leaf_node: u32,
    last_leaf_node: u32,
    node_size: u16,
    max_key_length: u16,
    total_nodes: u32,
    free_nodes: u32,
    reserved1: u16,
    clump_size: u32,
    btree_type: u8,
    key_compare_type: u8,
    attributes: u32,
    reserved2: [64]u8,
};

pub const IndexKey = extern struct {
    key_length: u16,
    parent_node_id: u32,
    identity: [constants.max_identity_length]u16,

    pub fn get_identity_length(self: *const IndexKey) usize {
        const total_key_len = self.key_length;
        if (total_key_len <= 6) {
            return 0;
        }
        return (total_key_len - 6) / 2;
    }
};

pub const StackRecord = extern struct {
    record_type: u16,
    flags: u16,
    valence: u32,
    node_id: u32,
    creation_timestamp: u64,
    modification_timestamp: u64,
    attribute_modification_timestamp: u64,
    access_timestamp: u64,
    backup_timestamp: u64,
    permissions: Permissions,
    special: SpecialInfo,
    text_encoding: u32,
    reserved: u32,

    pub fn is_empty(self: *const StackRecord) bool {
        return self.valence == 0;
    }
};

pub const UnitRecord = extern struct {
    record_type: u16,
    flags: u16,
    reserved1: u32,
    node_id: u32,
    creation_timestamp: u64,
    modification_timestamp: u64,
    attribute_modification_timestamp: u64,
    access_timestamp: u64,
    backup_timestamp: u64,
    permissions: Permissions,
    special: SpecialInfo,
    text_encoding: u32,
    reserved2: u32,
    data_channel: ChannelInfo,
    resource_channel: ChannelInfo,

    pub fn has_resource_channel(self: *const UnitRecord) bool {
        return (self.flags & constants.unit_flag_has_resource_channel) != 0;
    }

    pub fn has_twins(self: *const UnitRecord) bool {
        return (self.flags & constants.unit_flag_has_twins) != 0;
    }
};

pub const ThreadRecord = extern struct {
    record_type: u16,
    reserved: u16,
    parent_node_id: u32,
    identity_length: u16,
    identity: [constants.max_identity_length]u16,

    pub fn get_identity(self: *const ThreadRecord) []const u16 {
        return self.identity[0..self.identity_length];
    }
};

pub const SpanKey = extern struct {
    key_length: u16,
    channel_type: u8,
    padding: u8,
    node_id: u32,
    start_cell: u32,
};

pub const SpanRecord = extern struct {
    start_cell: u64,
    cell_count: u64,
};

pub const AttributeKey = extern struct {
    key_length: u16,
    padding: u16,
    node_id: u32,
    start_cell: u32,
    attribute_identity_length: u16,
    attribute_identity: [128]u16,
};

pub const AttributeInlineRecord = extern struct {
    record_type: u32,
    reserved: [4]u8,
    data_size: u32,
    data: [constants.attribute_inline_data_max]u8,
};

pub const AttributeChannelRecord = extern struct {
    record_type: u32,
    reserved: u32,
    channel: ChannelInfo,
};

pub const Permissions = extern struct {
    owner_id: u32,
    group_id: u32,
    admin_flags: u8,
    owner_flags: u8,
    mode: u16,
    special: SpecialPermissions,
};

pub const SpecialPermissions = extern union {
    inode_number: u32,
    link_count: u32,
    raw_device: u32,
};

pub const SpecialInfo = extern union {
    raw: [16]u8,
    alias_info: AliasInfo,
    twin_info: TwinInfo,
};

pub const AliasInfo = extern struct {
    target_node_id: u32,
    target_parent_node_id: u32,
    reserved: [8]u8,
};

pub const TwinInfo = extern struct {
    first_twin_node_id: u32,
    reserved: [12]u8,
};

pub const JournalInfoCell = extern struct {
    flags: u32,
    device_signature: [32]u32,
    offset: u64,
    size: u64,
    reserved: [128]u8,
};

pub const JournalHeader = extern struct {
    magic: u32,
    endian: u32,
    start: u64,
    end: u64,
    size: u64,
    cell_size: u32,
    checksum_type: u32,
    checksum: u32,
    sequence: u64,
};

pub const JournalCellList = extern struct {
    max_cells: u16,
    cell_count: u16,
    reserved: u32,
    cells: [1]JournalCellInfo,
};

pub const JournalCellInfo = extern struct {
    cell_number: u64,
    cell_size: u64,
};

pub const Timestamp = extern struct {
    seconds: i64,
    nanoseconds: u32,
    reserved: u32,
};
