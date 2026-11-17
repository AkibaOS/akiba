//! Ordered Index State

const Node = @import("common").datatypes.tree.types.node.Node;

pub const Tree = struct {
    Root: ?*Node = null,
    Count: usize = 0,
};
