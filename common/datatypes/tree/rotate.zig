//! Ordered Index Rotations And Balance Repair

const constants = @import("common").datatypes.tree.constants.balance;
const types = @import("common").datatypes.tree.types;

const Node = types.node.Node;
const Tree = types.index.Tree;

pub fn rebalance(index: *Tree, start: ?*Node) void {
    var current = start;
    while (current) |node| {
        update(node);
        var root = node;
        if (difference(node) > constants.MAX_DIFFERENCE) {
            if (difference(node.Left.?) < 0) _ = left(index, node.Left.?);
            root = right(index, node);
        } else if (difference(node) < -constants.MAX_DIFFERENCE) {
            if (difference(node.Right.?) > 0) _ = right(index, node.Right.?);
            root = left(index, node);
        }
        current = root.Parent;
    }
}

pub fn replace(index: *Tree, original: *Node, replacement: ?*Node) void {
    if (original.Parent) |parent| {
        if (parent.Left == original) {
            parent.Left = replacement;
        } else {
            parent.Right = replacement;
        }
    } else {
        index.Root = replacement;
    }
    if (replacement) |node| node.Parent = original.Parent;
}

fn left(index: *Tree, node: *Node) *Node {
    const root = node.Right.?;
    const middle = root.Left;
    replace(index, node, root);
    node.Right = middle;
    if (middle) |child| child.Parent = node;
    root.Left = node;
    node.Parent = root;
    update(node);
    update(root);
    return root;
}

fn right(index: *Tree, node: *Node) *Node {
    const root = node.Left.?;
    const middle = root.Right;
    replace(index, node, root);
    node.Left = middle;
    if (middle) |child| child.Parent = node;
    root.Right = node;
    node.Parent = root;
    update(node);
    update(root);
    return root;
}

fn height(node: ?*const Node) u8 {
    return if (node) |value| value.Height else constants.EMPTY_HEIGHT;
}

fn difference(node: *const Node) i16 {
    return @as(i16, height(node.Left)) - @as(i16, height(node.Right));
}

fn update(node: *Node) void {
    node.Height = @max(height(node.Left), height(node.Right)) + constants.LEAF_HEIGHT;
}
