//! AFS B-tree Types

const constants = @import("../constants/constants.zig");

pub const NodeDescriptor = extern struct {
    forward_link: u32 = 0,
    backward_link: u32 = 0,
    node_type: i8 = constants.btree.node_type_leaf,
    height: u8 = 0,
    record_count: u16 = 0,
    reserved: u16 = 0,

    pub fn is_leaf(self: *const NodeDescriptor) bool {
        return self.node_type == constants.btree.node_type_leaf;
    }

    pub fn is_index(self: *const NodeDescriptor) bool {
        return self.node_type == constants.btree.node_type_index;
    }

    pub fn is_header(self: *const NodeDescriptor) bool {
        return self.node_type == constants.btree.node_type_header;
    }

    pub fn is_map(self: *const NodeDescriptor) bool {
        return self.node_type == constants.btree.node_type_map;
    }
};

pub const HeaderRecord = extern struct {
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

    pub fn get_identity_length(self: *const IndexKey) usize {
        const total_key_len = self.key_length;
        if (total_key_len <= 6) {
            return 0;
        }
        return (total_key_len - 6) / 2;
    }
};
