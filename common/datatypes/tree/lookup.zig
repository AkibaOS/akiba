//! Ordered Index Lookup

const types = @import("common").datatypes.tree.types;

const Node = types.node.Node;
const Tree = types.index.Tree;

pub fn find(index: *const Tree, key: u128) ?*Node {
    var current = index.Root;
    while (current) |node| {
        if (key == node.Key) return node;
        current = if (key < node.Key) node.Left else node.Right;
    }
    return null;
}

pub fn first(index: *const Tree) ?*Node {
    var current = index.Root orelse return null;
    while (current.Left) |node| current = node;
    return current;
}

pub fn next(node: *const Node) ?*Node {
    if (node.Right) |right| {
        var current = right;
        while (current.Left) |child| current = child;
        return current;
    }
    var child: *const Node = node;
    var current = node.Parent;
    while (current) |parent| {
        if (parent.Left == child) return parent;
        child = parent;
        current = parent.Parent;
    }
    return null;
}
