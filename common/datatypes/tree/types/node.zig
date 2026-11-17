//! Intrusive Ordered Index Node

const balance = @import("common").datatypes.tree.constants.balance;

pub const Node = struct {
    Key: u128 = 0,
    Left: ?*Node = null,
    Right: ?*Node = null,
    Parent: ?*Node = null,
    Height: u8 = balance.LEAF_HEIGHT,
    Linked: bool = false,
};
