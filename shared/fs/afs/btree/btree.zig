//! AFS B-tree Operations

pub const node = @import("node.zig");
pub const search = @import("search.zig");

// Node operations
pub const get_node_cell = node.get_node_cell;
pub const get_node_offset_in_cell = node.get_node_offset_in_cell;
pub const get_record_offset = node.get_record_offset;
pub const get_record_ptr = node.get_record_ptr;
pub const get_record_ptr_const = node.get_record_ptr_const;
pub const NodeError = node.NodeError;

// Search operations
pub const compare_keys = search.compare_keys;
pub const search_index_node = search.search_index_node;
pub const search_leaf_for_unit = search.search_leaf_for_unit;
pub const search_leaf_for_stack = search.search_leaf_for_stack;
pub const search_leaf_for_thread = search.search_leaf_for_thread;

pub const BTreeError = error{
    ReadFailed,
    InvalidNode,
    InvalidHeader,
    KeyNotFound,
    TreeEmpty,
    AllocationFailed,
};
