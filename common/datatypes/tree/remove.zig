//! Ordered Index Removal

const lookup = @import("common").datatypes.tree.lookup;
const rotate = @import("common").datatypes.tree.rotate;
const types = @import("common").datatypes.tree.types;

const Node = types.node.Node;
const Tree = types.index.Tree;

pub fn remove(index: *Tree, node: *Node) bool {
    if (!node.Linked or index.Count == 0 or lookup.find(index, node.Key) != node) return false;
    var start: ?*Node = null;
    if (node.Left == null) {
        start = node.Parent;
        rotate.replace(index, node, node.Right);
    } else if (node.Right == null) {
        start = node.Parent;
        rotate.replace(index, node, node.Left);
    } else {
        var successor = node.Right.?;
        while (successor.Left) |child| successor = child;
        if (successor.Parent == node) {
            start = successor;
        } else {
            start = successor.Parent;
            rotate.replace(index, successor, successor.Right);
            successor.Right = node.Right;
            successor.Right.?.Parent = successor;
        }
        rotate.replace(index, node, successor);
        successor.Left = node.Left;
        successor.Left.?.Parent = successor;
    }
    node.* = .{ .Key = node.Key };
    index.Count -= 1;
    rotate.rebalance(index, start);
    return true;
}
