//! Deterministic Owned AFS Manifest Regressions

const std = @import("std");

const collect = @import("mkafsdisk").catalog.collect;
const constants = @import("tests").fast.toolchain.image.constants.capacity;
const pack = @import("mkafsdisk").catalog.pack;
const strings = @import("tests").fast.toolchain.image.strings.capacity;
const types = @import("mkafsdisk").types;

pub fn emptySourceRetainsOrigin() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const source = try temporary.dir.realpathAlloc(std.testing.allocator, strings.CURRENT_DIRECTORY);
    defer std.testing.allocator.free(source);
    var manifest = try collect.collect(std.testing.allocator, source);
    defer manifest.deinit();
    try std.testing.expectEqual(@as(usize, 1), manifest.Entries.len);
    try std.testing.expectEqual(@as(u32, 0), manifest.UnitCount);
    try std.testing.expectEqual(@as(u32, 1), manifest.StackCount);
    try std.testing.expectEqual(constants.FIRST_USER_ID, manifest.NextNodeId);
    const origin = manifest.Entries[0];
    try std.testing.expectEqual(constants.ORIGIN_PARENT, origin.ParentNodeId);
    try std.testing.expectEqual(constants.ORIGIN_ID, origin.NodeId);
    try std.testing.expectEqual(types.catalog.entry.EntryKind.Stack, origin.Kind);
    try std.testing.expectEqualStrings(strings.EMPTY_IDENTITY, origin.Identity);
    var tree = try pack.pack(std.testing.allocator, manifest.Entries);
    defer tree.deinit();
    try std.testing.expectEqual(@as(usize, constants.EMPTY_TREE_NODES), tree.Nodes.len);
    try std.testing.expectEqual(@as(u16, 1), tree.Header.Depth);
    try std.testing.expectEqual(constants.FIRST_LEAF, tree.Header.RootNode);
    try std.testing.expectEqual(constants.FIRST_LEAF, tree.Header.FirstLeafNode);
    try std.testing.expectEqual(constants.FIRST_LEAF, tree.Header.LastLeafNode);
    try std.testing.expectEqual(@as(u32, 1), tree.Header.LeafRecordCount);
}

pub fn creationOrderDoesNotDetermineObjectIds() !void {
    var first = std.testing.tmpDir(.{});
    defer first.cleanup();
    var second = std.testing.tmpDir(.{});
    defer second.cleanup();
    try createSource(first.dir, false);
    try createSource(second.dir, true);
    const first_path = try first.dir.realpathAlloc(std.testing.allocator, strings.CURRENT_DIRECTORY);
    defer std.testing.allocator.free(first_path);
    const second_path = try second.dir.realpathAlloc(std.testing.allocator, strings.CURRENT_DIRECTORY);
    defer std.testing.allocator.free(second_path);
    var left = try collect.collect(std.testing.allocator, first_path);
    defer left.deinit();
    var right = try collect.collect(std.testing.allocator, second_path);
    defer right.deinit();
    try std.testing.expectEqual(constants.MANIFEST_ENTRIES, left.Entries.len);
    try std.testing.expectEqual(constants.MANIFEST_ENTRIES, right.Entries.len);
    try std.testing.expectEqual(constants.MANIFEST_UNITS, left.UnitCount);
    try std.testing.expectEqual(constants.MANIFEST_STACKS, left.StackCount);
    try std.testing.expectEqual(constants.MANIFEST_NEXT_ID, left.NextNodeId);
    try std.testing.expectEqual(left.UnitCount, right.UnitCount);
    try std.testing.expectEqual(left.StackCount, right.StackCount);
    try std.testing.expectEqual(left.NextNodeId, right.NextNodeId);
    for (left.Entries, right.Entries) |expected, actual| {
        try std.testing.expectEqual(expected.ParentNodeId, actual.ParentNodeId);
        try std.testing.expectEqual(expected.NodeId, actual.NodeId);
        try std.testing.expectEqual(expected.Kind, actual.Kind);
        try std.testing.expectEqual(expected.LogicalSize, actual.LogicalSize);
        try std.testing.expectEqualStrings(expected.Identity, actual.Identity);
    }
    try expectIdentity(&left, constants.ORIGIN_ID, strings.ALPHA_PATH, constants.ALPHA_ID);
    try expectIdentity(&left, constants.ORIGIN_ID, strings.BETA_PATH, constants.BETA_ID);
    try expectIdentity(&left, constants.ORIGIN_ID, strings.NESTED_PATH, constants.NESTED_ID);
    try expectIdentity(&left, constants.NESTED_ID, strings.CHILD_IDENTITY, constants.CHILD_ID);
}

pub fn missingSourceFailsInsteadOfProducingOriginOnly() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const directory = try temporary.dir.realpathAlloc(std.testing.allocator, strings.CURRENT_DIRECTORY);
    defer std.testing.allocator.free(directory);
    const source = try std.fs.path.join(std.testing.allocator, &.{ directory, strings.MISSING_PATH });
    defer std.testing.allocator.free(source);
    try std.testing.expectError(error.FileNotFound, collect.collect(std.testing.allocator, source));
}

pub fn identityAndCountExhaustionPreserveCounters() !void {
    var next_node_id = constants.LAST_ASSIGNABLE_ID;
    try std.testing.expectEqual(constants.LAST_ASSIGNABLE_ID, try collect.takeNodeId(&next_node_id));
    try std.testing.expectEqual(constants.EXHAUSTED_ID, next_node_id);
    try std.testing.expectError(error.Overflow, collect.takeNodeId(&next_node_id));
    try std.testing.expectEqual(constants.EXHAUSTED_ID, next_node_id);
    var count = constants.LAST_ASSIGNABLE_ID;
    try collect.incrementCount(&count);
    try std.testing.expectEqual(constants.EXHAUSTED_ID, count);
    try std.testing.expectError(error.Overflow, collect.incrementCount(&count));
    try std.testing.expectEqual(constants.EXHAUSTED_ID, count);
}

fn createSource(directory: std.fs.Dir, reverse: bool) !void {
    if (reverse) {
        try directory.makePath(strings.NESTED_PATH);
        try directory.writeFile(.{ .sub_path = strings.CHILD_PATH, .data = strings.PAYLOAD });
        try directory.writeFile(.{ .sub_path = strings.BETA_PATH, .data = strings.PAYLOAD });
        try directory.writeFile(.{ .sub_path = strings.ALPHA_PATH, .data = strings.PAYLOAD });
    } else {
        try directory.writeFile(.{ .sub_path = strings.ALPHA_PATH, .data = strings.PAYLOAD });
        try directory.writeFile(.{ .sub_path = strings.BETA_PATH, .data = strings.PAYLOAD });
        try directory.makePath(strings.NESTED_PATH);
        try directory.writeFile(.{ .sub_path = strings.CHILD_PATH, .data = strings.PAYLOAD });
    }
    try directory.writeFile(.{ .sub_path = strings.HIDDEN_PATH, .data = strings.PAYLOAD });
}

fn expectIdentity(manifest: *const types.manifest.Manifest, parent: u32, identity: []const u8, expected_id: u32) !void {
    for (manifest.Entries) |entry| {
        if (entry.ParentNodeId != parent or !std.mem.eql(u8, entry.Identity, identity)) continue;
        try std.testing.expectEqual(expected_id, entry.NodeId);
        return;
    }
    return error.TestExpectedEqual;
}
