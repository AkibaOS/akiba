//! Stable Root Owned Table Frame Metadata

const kagami = @import("mirai").kagami.types.kagami;
const tree = @import("common").datatypes.tree;

pub const Frame = struct {
    Owner: *kagami.Kagami,
    PA: u64,
    Index: tree.types.node.Node = .{},
    Previous: ?*Frame = null,
    Next: ?*Frame = null,
    Visited: bool = false,
};
