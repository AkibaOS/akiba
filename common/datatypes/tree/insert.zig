//! Ordered Index Insertion

const std = @import("std");

const rotate = @import("common").datatypes.tree.rotate;
const types = @import("common").datatypes.tree.types;

const Node = types.node.Node;
const Tree = types.index.Tree;

pub fn insert(index: *Tree, node: *Node, key: u128) bool {
    if (node.Linked or index.Count == std.math.maxInt(usize)) return false;
    var current = index.Root;
    var parent: ?*Node = null;
    while (current) |value| {
        if (key == value.Key) return false;
        parent = value;
        current = if (key < value.Key) value.Left else value.Right;
    }
    node.* = .{ .Key = key, .Parent = parent, .Linked = true };
    if (parent) |value| {
        if (key < value.Key) {
            value.Left = node;
        } else {
            value.Right = node;
        }
    } else {
        index.Root = node;
    }
    index.Count += 1;
    rotate.rebalance(index, parent);
    return true;
}
