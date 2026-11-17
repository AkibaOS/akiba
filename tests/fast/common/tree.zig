//! Intrusive Ordered Index Regressions

const std = @import("std");

const inputs = @import("tests").constants.tree;
const tree = @import("common").datatypes.tree;
const types = @import("tests").types.tree;

const Node = tree.types.node.Node;
const Tree = tree.types.index.Tree;
const Validation = types.Validation;

pub fn empty() !void {
    var index: Tree = .{};
    var foreign_node: Node = .{};
    try std.testing.expect(tree.lookup.first(&index) == null);
    try std.testing.expect(tree.lookup.find(&index, 0) == null);
    try std.testing.expect(!tree.remove.remove(&index, &foreign_node));
    try validate(&index);
}

pub fn rotations() !void {
    for (inputs.ROTATIONS) |keys| {
        var index: Tree = .{};
        var nodes = [_]Node{.{}} ** 3;
        for (&nodes, keys) |*node, key| {
            try std.testing.expect(tree.insert.insert(&index, node, key));
            try validate(&index);
        }
        try std.testing.expectEqual(@as(u128, 2), index.Root.?.Key);
        try expectKeys(&index, &.{ 1, 2, 3 });
        for (&nodes, keys) |*node, key| try std.testing.expect(tree.lookup.find(&index, key) == node);
    }
}

pub fn duplicate() !void {
    var index: Tree = .{};
    var original: Node = .{};
    var duplicate_node: Node = .{};
    try std.testing.expect(tree.insert.insert(&index, &original, 7));
    try std.testing.expect(!tree.insert.insert(&index, &duplicate_node, 7));
    try std.testing.expect(!tree.insert.insert(&index, &original, 7));
    try std.testing.expect(tree.lookup.find(&index, 7) == &original);
    try std.testing.expect(duplicate_node.Parent == null and duplicate_node.Left == null and duplicate_node.Right == null);
    try std.testing.expectEqual(@as(usize, 1), index.Count);
    try validate(&index);
}

pub fn removal() !void {
    var index: Tree = .{};
    var nodes = [_]Node{.{}} ** inputs.REMOVE_KEYS.len;
    var present = [_]bool{true} ** nodes.len;
    for (&nodes, inputs.REMOVE_KEYS) |*node, key| try std.testing.expect(tree.insert.insert(&index, node, key));
    for (inputs.REMOVAL_ORDER) |position| {
        try std.testing.expect(tree.remove.remove(&index, &nodes[position]));
        present[position] = false;
        try std.testing.expect(nodes[position].Parent == null and nodes[position].Left == null and nodes[position].Right == null);
        try std.testing.expect(!tree.remove.remove(&index, &nodes[position]));
        for (&nodes, inputs.REMOVE_KEYS, present) |*node, key, retained| {
            try std.testing.expect(tree.lookup.find(&index, key) == if (retained) node else null);
        }
        try validate(&index);
    }
    try std.testing.expect(index.Root == null and index.Count == 0);
}

pub fn foreign() !void {
    var index: Tree = .{};
    var other: Tree = .{};
    var original: Node = .{};
    var foreign_node: Node = .{};
    try std.testing.expect(tree.insert.insert(&index, &original, 7));
    try std.testing.expect(tree.insert.insert(&other, &foreign_node, 7));
    try std.testing.expect(!tree.remove.remove(&index, &foreign_node));
    try std.testing.expect(!tree.insert.insert(&index, &foreign_node, 9));
    try std.testing.expect(tree.lookup.find(&index, 9) == null);
    try std.testing.expect(tree.lookup.find(&index, 7) == &original and tree.lookup.find(&other, 7) == &foreign_node);
    try validate(&index);
    try validate(&other);
}

pub fn wide() !void {
    var index: Tree = .{};
    var nodes = [_]Node{.{}} ** inputs.WIDE_KEYS.len;
    for (&nodes, 0..) |*node, position| {
        try std.testing.expect(tree.insert.insert(&index, node, inputs.WIDE_KEYS[inputs.WIDE_KEYS.len - position - 1]));
    }
    try expectKeys(&index, &inputs.WIDE_KEYS);
    for (inputs.WIDE_KEYS) |key| try std.testing.expect(tree.lookup.find(&index, key).?.Key == key);
    try validate(&index);
}

pub fn bounds() !void {
    var index: Tree = .{};
    var nodes = [_]Node{.{}} ** inputs.BOUND_KEYS.len;
    try std.testing.expect(tree.lookup.lowerBound(&index, 0) == null);
    for (&nodes, inputs.BOUND_KEYS) |*node, key| try std.testing.expect(tree.insert.insert(&index, node, key));
    for (inputs.BOUND_CASES) |fixture| {
        const found = tree.lookup.lowerBound(&index, fixture.Key);
        if (fixture.Expected) |key| {
            try std.testing.expect(found != null);
            try std.testing.expectEqual(key, found.?.Key);
        } else {
            try std.testing.expect(found == null);
        }
    }
    try validate(&index);
    var wide_index: Tree = .{};
    var wide_nodes = [_]Node{.{}} ** inputs.WIDE_KEYS.len;
    for (&wide_nodes, inputs.WIDE_KEYS) |*node, key| try std.testing.expect(tree.insert.insert(&wide_index, node, key));
    try std.testing.expectEqual(inputs.WIDE_BOUND_RESULT, tree.lookup.lowerBound(&wide_index, inputs.WIDE_BOUND_QUERY).?.Key);
    try validate(&wide_index);
}

pub fn growth() !void {
    const nodes = try std.testing.allocator.alloc(Node, inputs.LARGE_COUNT);
    defer std.testing.allocator.free(nodes);
    @memset(nodes, .{});
    var index: Tree = .{};
    for (0..nodes.len) |position| {
        const key = (position * inputs.PERMUTATION_FACTOR) % nodes.len;
        try std.testing.expect(tree.insert.insert(&index, &nodes[key], key));
        if (position % inputs.VALIDATION_INTERVAL == 0) try validate(&index);
    }
    try std.testing.expectEqual(nodes.len, index.Count);
    for (0..nodes.len) |key| try std.testing.expect(tree.lookup.find(&index, key) == &nodes[key]);
    var current = tree.lookup.first(&index);
    for (0..nodes.len) |key| {
        try std.testing.expect(current == &nodes[key]);
        current = tree.lookup.next(current.?);
    }
    try std.testing.expect(current == null);
    try validate(&index);
    for (0..nodes.len) |position| {
        const key = (position * inputs.PERMUTATION_FACTOR) % nodes.len;
        try std.testing.expect(tree.remove.remove(&index, &nodes[key]));
        try std.testing.expect(tree.lookup.find(&index, key) == null);
        if (position % inputs.VALIDATION_INTERVAL == 0) try validate(&index);
    }
    try validate(&index);
    try std.testing.expect(index.Root == null and index.Count == 0);
    for (nodes, 0..) |_, key| try std.testing.expect(tree.insert.insert(&index, &nodes[key], key));
    try validate(&index);
    while (tree.lookup.first(&index)) |node| try std.testing.expect(tree.remove.remove(&index, node));
    try validate(&index);
}

fn expectKeys(index: *const Tree, keys: []const u128) !void {
    var current = tree.lookup.first(index);
    for (keys) |key| {
        try std.testing.expect(current != null);
        try std.testing.expectEqual(key, current.?.Key);
        current = tree.lookup.next(current.?);
    }
    try std.testing.expect(current == null);
}

fn validate(index: *const Tree) !void {
    const result = try validateNode(index.Root, null, 0);
    try std.testing.expectEqual(index.Count, result.Count);
}

fn validateNode(node: ?*const Node, parent: ?*const Node, depth: usize) anyerror!Validation {
    const current = node orelse return .{};
    try std.testing.expect(depth < inputs.MAX_TEST_DEPTH);
    try std.testing.expect(current.Parent == parent);
    const left = try validateNode(current.Left, current, depth + 1);
    const right = try validateNode(current.Right, current, depth + 1);
    if (left.Maximum) |key| try std.testing.expect(key < current.Key);
    if (right.Minimum) |key| try std.testing.expect(key > current.Key);
    const height = @max(left.Height, right.Height) + 1;
    const difference = @as(i16, left.Height) - @as(i16, right.Height);
    try std.testing.expect(difference >= -1 and difference <= 1);
    try std.testing.expectEqual(height, current.Height);
    return .{
        .Count = left.Count + right.Count + 1,
        .Height = height,
        .Minimum = left.Minimum orelse current.Key,
        .Maximum = right.Maximum orelse current.Key,
    };
}
