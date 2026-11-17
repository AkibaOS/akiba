//! Stable Sparse Crimson Owner Port Record

const tree = @import("common").datatypes.tree;
const types = @import("mirai").crimson.types;

pub const Entry = struct {
    Index: tree.types.node.Node = .{},
    OwnerId: u64 = 0,
    Ports: types.ports.array.PortArray = types.ports.array.PortArray.EMPTY,
};
