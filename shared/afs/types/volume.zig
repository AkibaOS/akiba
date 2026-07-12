//! AFS Volume Types

const constants = @import("../constants/constants.zig");

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
    journal_info_cell: u64 = constants.sizes.journal_info_cell,
    journal_info_size: u32 = constants.sizes.journal_header_size,
    compression_type: u32 = constants.flags.compression_none,
    encryption_type: u32 = constants.flags.encryption_none,
    reserved: [64]u8 = [_]u8{0} ** 64,

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
    start_cell: u64 = 0,
    cell_count: u64 = 0,

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
    logical_size: u64 = 0,
    physical_size: u64 = 0,
    clump_size: u32 = 0,
    total_cells: u32 = 0,
    spans: [constants.span_inline_count]SpanDescriptor = [_]SpanDescriptor{.{}} ** constants.span_inline_count,

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
