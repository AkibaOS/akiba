//! AFS B-tree Types

const constants = @import("../constants/constants.zig");

pub const NodeDescriptor = extern struct {
    ForwardLink: u32 = 0,
    BackwardLink: u32 = 0,
    NodeType: i8 = constants.btree.NODE_TYPE_LEAF,
    Height: u8 = 0,
    RecordCount: u16 = 0,
    Reserved: u16 = 0,

    pub fn isLeaf(self: *const NodeDescriptor) bool {
        return self.NodeType == constants.btree.NODE_TYPE_LEAF;
    }

    pub fn isIndex(self: *const NodeDescriptor) bool {
        return self.NodeType == constants.btree.NODE_TYPE_INDEX;
    }

    pub fn isHeader(self: *const NodeDescriptor) bool {
        return self.NodeType == constants.btree.NODE_TYPE_HEADER;
    }

    pub fn isMap(self: *const NodeDescriptor) bool {
        return self.NodeType == constants.btree.NODE_TYPE_MAP;
    }
};

pub const HeaderRecord = extern struct {
    Depth: u16 = 1,
    RootNode: u32 = 1,
    LeafRecordCount: u32 = 0,
    FirstLeafNode: u32 = 1,
    LastLeafNode: u32 = 1,
    NodeSize: u16 = 0,
    MaxKeyLength: u16 = 0,
    TotalNodes: u32 = 0,
    FreeNodes: u32 = 0,
    Reserved1: u16 = 0,
    ClumpSize: u32 = 0,
    BTreeType: u8 = 0,
    KeyCompareType: u8 = 0,
    Attributes: u32 = 0,
    Reserved2: [64]u8 = [_]u8{0} ** 64,
};

pub const IndexKey = extern struct {
    KeyLength: u16 = 0,
    ParentNodeId: u32 = 0,
    Identity: [256]u16 = [_]u16{0} ** 256,

    pub fn getIdentityLength(self: *align(1) const IndexKey) usize {
        const total_key_length = self.KeyLength;
        if (total_key_length <= constants.btree.INDEX_KEY_HEADER_SIZE) {
            return 0;
        }
        return (total_key_length - constants.btree.INDEX_KEY_HEADER_SIZE) / @sizeOf(u16);
    }
};
