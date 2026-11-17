//! Bulk AFS Catalog Packing And Production Lookup Regressions

const std = @import("std");

const afs = @import("shared").afs;
const constants = @import("tests").fast.toolchain.image.constants.capacity;
const encode = @import("mkafsdisk").catalog.encode;
const pack = @import("mkafsdisk").catalog.pack;
const strings = @import("tests").fast.toolchain.image.strings.capacity;
const tool = @import("mkafsdisk");
const types = @import("tests").fast.toolchain.image.types.capacity;

pub fn recordPackingRejectsOffsetCollisions() !void {
    try std.testing.expect(try pack.recordFits(constants.DESCRIPTOR_BYTES, 0, constants.MAXIMUM_PACKED_RECORD));
    try std.testing.expectError(error.RecordTooLarge, pack.recordFits(constants.DESCRIPTOR_BYTES, 0, constants.OVERSIZED_RECORD));
    try std.testing.expectError(error.RecordTooLarge, pack.recordFits(constants.DESCRIPTOR_BYTES, 0, std.math.maxInt(usize)));
    try std.testing.expect(!try pack.recordFits(constants.EXACT_RECORD_END, constants.EXACT_OFFSETS.len, constants.EXACT_RECORD_BYTES));
}

pub fn exactNodeFillSplitsOnlyTheNextRecord() !void {
    var fixture: types.ExactFixture = undefined;
    for (&fixture.Names, 0..) |*name, index| {
        @memset(name, constants.NAME_BYTE);
        name[name.len - 1] = constants.DIGIT_ZERO + @as(u8, @intCast(index));
        fixture.Entries[index] = .{
            .ParentNodeId = constants.ORIGIN_ID,
            .NodeId = constants.FIRST_USER_ID + @as(u32, @intCast(index)),
            .Identity = name,
            .Kind = .Unit,
        };
        fixture.Spans[index] = .{};
    }
    var exact = try pack.pack(std.testing.allocator, fixture.Entries[0..constants.EXACT_OFFSETS.len]);
    defer exact.deinit();
    try std.testing.expectEqual(@as(usize, constants.EMPTY_TREE_NODES), exact.Nodes.len);
    try std.testing.expectEqual(constants.FIRST_LEAF, exact.Header.RootNode);
    var buffer: [constants.CELL_BYTES]u8 = @splat(constants.FILL_BYTE);
    try encode.encode(&exact, constants.FIRST_LEAF, fixture.Entries[0..constants.EXACT_OFFSETS.len], fixture.Spans[0..constants.EXACT_OFFSETS.len], &buffer);
    try std.testing.expect(afs.btree.validate.catalogNode(&buffer));
    for (constants.EXACT_OFFSETS, 0..) |expected, index| {
        const position = constants.CELL_BYTES - constants.OFFSET_BYTES * (index + 1);
        try std.testing.expectEqual(expected, std.mem.readInt(u16, buffer[position..][0..constants.OFFSET_BYTES], .little));
        try std.testing.expect(std.mem.allEqual(u8, buffer[@as(usize, expected) + 2 ..][0..2], 0));
    }
    var split = try pack.pack(std.testing.allocator, &fixture.Entries);
    defer split.deinit();
    try std.testing.expectEqual(@as(usize, constants.EXACT_NODES), split.Nodes.len);
    try std.testing.expectEqual(constants.EXACT_ROOT, split.Header.RootNode);
    try std.testing.expectEqual(@as(u16, 2), split.Header.Depth);
    try std.testing.expectEqual(constants.FIRST_LEAF, split.Header.FirstLeafNode);
    try std.testing.expectEqual(constants.EXACT_LEAVES, split.Header.LastLeafNode);
    try std.testing.expectEqual(constants.EXACT_OFFSETS.len, split.Nodes[constants.FIRST_LEAF].Records.len);
    try std.testing.expectEqual(@as(usize, 1), split.Nodes[constants.EXACT_LEAVES].Records.len);
}

pub fn maximumKeyAndHeaderUseIndependentWireBytes() !void {
    const identity = [_]u8{constants.NAME_BYTE} ** constants.MAXIMUM_NAME_BYTES;
    const entries = [_]tool.types.catalog.Entry{.{
        .ParentNodeId = constants.KEY_PARENT,
        .NodeId = constants.KEY_NODE,
        .Identity = &identity,
        .Kind = .Unit,
        .Timestamp = constants.TIMESTAMP,
    }};
    const spans = [_]afs.types.volume.SpanDescriptor{.{}};
    var tree = try pack.pack(std.testing.allocator, &entries);
    defer tree.deinit();
    var buffer: [constants.CELL_BYTES]u8 = @splat(constants.FILL_BYTE);
    try encode.encode(&tree, constants.FIRST_LEAF, &entries, &spans, &buffer);
    try std.testing.expect(afs.btree.validate.catalogNode(&buffer));
    try std.testing.expectEqualSlices(u8, &constants.MAXIMUM_KEY_LE, buffer[constants.DESCRIPTOR_BYTES..][0..2]);
    try std.testing.expect(std.mem.allEqual(u8, buffer[constants.KEY_PADDING_OFFSET..][0..2], 0));
    try std.testing.expectEqualSlices(u8, &constants.KEY_PARENT_LE, buffer[constants.KEY_PARENT_OFFSET..][0..4]);
    for (0..constants.MAXIMUM_NAME_BYTES) |index| {
        const position = constants.KEY_IDENTITY_OFFSET + constants.OFFSET_BYTES * index;
        try std.testing.expectEqual(constants.NAME_BYTE, buffer[position]);
        try std.testing.expectEqual(@as(u8, 0), buffer[position + 1]);
    }
    try std.testing.expectEqualSlices(u8, &constants.UNIT_TYPE_LE, buffer[constants.MAXIMUM_PAYLOAD_OFFSET..][0..2]);
    try std.testing.expectEqualSlices(u8, &constants.KEY_NODE_LE, buffer[constants.PAYLOAD_NODE_OFFSET..][0..4]);
    try std.testing.expect(std.mem.allEqual(u8, buffer[constants.PAYLOAD_PADDING_OFFSET..][0..4], 0));
    try std.testing.expectEqualSlices(u8, &constants.TIMESTAMP_LE, buffer[constants.PAYLOAD_TIMESTAMP_OFFSET..][0..8]);
    try std.testing.expect(std.mem.allEqual(u8, buffer[constants.MAXIMUM_RECORD_END .. constants.CELL_BYTES - constants.OFFSET_BYTES], 0));
    @memset(&buffer, constants.FILL_BYTE);
    try encode.encode(&tree, constants.HEADER_NODE, &entries, &spans, &buffer);
    const descriptor = std.mem.bytesToValue(afs.types.btree.NodeDescriptor, buffer[0..constants.DESCRIPTOR_BYTES]);
    try std.testing.expect(descriptor.isHeader());
    try std.testing.expectEqual(constants.HEADER_RECORD_BYTES, std.mem.readInt(u16, buffer[constants.HEADER_RECORD_COUNT_OFFSET..][0..2], .little));
    try std.testing.expectEqualSlices(u8, &constants.MAXIMUM_KEY_LE, buffer[constants.HEADER_MAXIMUM_KEY_OFFSET..][0..2]);
    try std.testing.expectEqual(constants.EMPTY_TREE_NODES, std.mem.readInt(u32, buffer[constants.HEADER_TOTAL_NODES_OFFSET..][0..4], .little));
    try std.testing.expectEqual(@as(u16, constants.DESCRIPTOR_BYTES), std.mem.readInt(u16, buffer[constants.CELL_BYTES - constants.OFFSET_BYTES ..][0..2], .little));
    try std.testing.expectEqual(constants.MAXIMUM_KEY_BYTES, tree.Header.MaxKeyLength);
    try std.testing.expectEqual(@as(u32, 0), tree.Header.FreeNodes);
}

pub fn globalOrderingAndParentIsolation() !void {
    var tree = try pack.pack(std.testing.allocator, &constants.ORDERED_INPUT);
    defer tree.deinit();
    try std.testing.expectEqual(@as(usize, constants.EMPTY_TREE_NODES), tree.Nodes.len);
    try std.testing.expectEqual(constants.SORTED_ENTRY_INDICES.len, tree.Nodes[constants.FIRST_LEAF].Records.len);
    for (constants.SORTED_ENTRY_INDICES, tree.Nodes[constants.FIRST_LEAF].Records) |expected, actual| {
        try std.testing.expectEqual(expected, actual.EntryIndex);
    }
    const spans = [_]afs.types.volume.SpanDescriptor{.{}} ** constants.ORDERED_INPUT.len;
    const parent = constants.ORDERED_INPUT[3].ParentNodeId;
    const first = (try findUnit(&tree, &constants.ORDERED_INPUT, &spans, parent, &strings.FIRST_UTF16)) orelse return error.TestExpectedEqual;
    const prefix = (try findUnit(&tree, &constants.ORDERED_INPUT, &spans, parent, &strings.PREFIX_UTF16)) orelse return error.TestExpectedEqual;
    const second = (try findUnit(&tree, &constants.ORDERED_INPUT, &spans, parent, &strings.SECOND_UTF16)) orelse return error.TestExpectedEqual;
    const lower = (try findUnit(&tree, &constants.ORDERED_INPUT, &spans, parent, &strings.LOWER_UTF16)) orelse return error.TestExpectedEqual;
    const other = (try findUnit(&tree, &constants.ORDERED_INPUT, &spans, constants.ORDERED_INPUT[0].ParentNodeId, &strings.FIRST_UTF16)) orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(constants.ORDERED_INPUT[3].NodeId, first.NodeId);
    try std.testing.expectEqual(constants.ORDERED_INPUT[2].NodeId, prefix.NodeId);
    try std.testing.expectEqual(constants.ORDERED_INPUT[4].NodeId, second.NodeId);
    try std.testing.expectEqual(constants.ORDERED_INPUT[1].NodeId, lower.NodeId);
    try std.testing.expectEqual(constants.ORDERED_INPUT[0].NodeId, other.NodeId);
    try std.testing.expect(try findUnit(&tree, &constants.ORDERED_INPUT, &spans, constants.ORIGIN_PARENT, &strings.FIRST_UTF16) == null);
    try std.testing.expect(try findUnit(&tree, &constants.ORDERED_INPUT, &spans, constants.ORDERED_INPUT[0].ParentNodeId, &strings.SECOND_UTF16) == null);
}

pub fn duplicateAndInvalidCatalogEntriesAreRejected() !void {
    var duplicate = [_]tool.types.catalog.Entry{ constants.ORDERED_INPUT[3], constants.ORDERED_INPUT[3] };
    duplicate[1].NodeId = constants.BETA_ID;
    try std.testing.expectError(error.DuplicateKey, pack.pack(std.testing.allocator, &duplicate));
    const oversized = [_]u8{constants.NAME_BYTE} ** constants.INVALID_NAME_BYTES;
    for ([_][]const u8{ &oversized, strings.INVALID_SLASH, strings.INVALID_BACKSLASH, strings.EMPTY_IDENTITY }) |identity| {
        var entry = constants.ORDERED_INPUT[3];
        entry.Identity = identity;
        try std.testing.expectError(error.InvalidIdentity, pack.pack(std.testing.allocator, &.{entry}));
    }
    var excessive = constants.ORDERED_INPUT[3];
    excessive.LogicalSize = std.math.maxInt(u64);
    try std.testing.expectError(error.Overflow, pack.pack(std.testing.allocator, &.{excessive}));
    try std.testing.expectError(error.InvalidCatalog, pack.pack(std.testing.allocator, &.{}));
}

pub fn multiLevelMaximumKeyRoutingAndLinks() !void {
    var fixture: types.DeepFixture = undefined;
    initializeDeep(&fixture);
    var tree = try pack.pack(std.testing.allocator, &fixture.Entries);
    defer tree.deinit();
    try std.testing.expect(tree.Nodes.len > constants.FORMER_INDEX_NODES);
    try std.testing.expectEqual(@as(usize, constants.DEEP_NODES), tree.Nodes.len);
    try std.testing.expectEqual(constants.DEEP_DEPTH, tree.Header.Depth);
    try std.testing.expectEqual(constants.DEEP_ROOT, tree.Header.RootNode);
    try std.testing.expectEqual(constants.FIRST_LEAF, tree.Header.FirstLeafNode);
    try std.testing.expectEqual(constants.DEEP_LEAVES, tree.Header.LastLeafNode);
    try std.testing.expectEqual(@as(u32, constants.DEEP_RECORDS), tree.Header.LeafRecordCount);
    try std.testing.expectEqual(constants.DEEP_NODES, tree.Header.TotalNodes);
    try std.testing.expectEqual(@as(u32, 0), tree.Header.FreeNodes);
    for (tree.Nodes[1..], 1..) |planned, index| {
        var buffer: [constants.CELL_BYTES]u8 = @splat(constants.FILL_BYTE);
        try encode.encode(&tree, @intCast(index), &fixture.Entries, &fixture.Spans, &buffer);
        try std.testing.expect(afs.btree.validate.catalogNode(&buffer));
        const descriptor = std.mem.bytesToValue(afs.types.btree.NodeDescriptor, buffer[0..constants.DESCRIPTOR_BYTES]);
        const previous: u32 = if (index > 1 and tree.Nodes[index - 1].Height == planned.Height) @intCast(index - 1) else 0;
        const next: u32 = if (index + 1 < tree.Nodes.len and tree.Nodes[index + 1].Height == planned.Height) @intCast(index + 1) else 0;
        try std.testing.expectEqual(previous, descriptor.BackwardLink);
        try std.testing.expectEqual(next, descriptor.ForwardLink);
        try std.testing.expectEqual(planned.Height, descriptor.Height);
        try std.testing.expectEqual(planned.Records.len, descriptor.RecordCount);
        if (planned.Height > 1) {
            try std.testing.expect(planned.Records.len > 1);
            for (planned.Records) |record| {
                const child = tree.Nodes[record.ChildNode];
                try std.testing.expectEqual(child.Records[child.Records.len - 1].EntryIndex, record.EntryIndex);
            }
        }
    }
    for (fixture.Names, 0..) |name, index| {
        var identity: [180]u16 = undefined;
        for (name, 0..) |byte, position| identity[position] = byte;
        const found = (try findUnit(&tree, &fixture.Entries, &fixture.Spans, constants.ORIGIN_ID, &identity)) orelse return error.TestExpectedEqual;
        try std.testing.expectEqual(constants.FIRST_USER_ID + @as(u32, @intCast(index)), found.NodeId);
        try std.testing.expect(try findUnit(&tree, &fixture.Entries, &fixture.Spans, constants.ORIGIN_PARENT, &identity) == null);
        var missing = name;
        setSuffix(&missing, index * constants.GAP_STRIDE + 1);
        for (missing, 0..) |byte, position| identity[position] = byte;
        try std.testing.expect(try findUnit(&tree, &fixture.Entries, &fixture.Spans, constants.ORIGIN_ID, &identity) == null);
    }
    var after = fixture.Names[0];
    setSuffix(&after, constants.AFTER_LAST_SUFFIX);
    var after_utf16: [180]u16 = undefined;
    for (after, 0..) |byte, index| after_utf16[index] = byte;
    try std.testing.expect(try findUnit(&tree, &fixture.Entries, &fixture.Spans, constants.ORIGIN_ID, &after_utf16) == null);
    try std.testing.expect(try findUnit(&tree, &fixture.Entries, &fixture.Spans, constants.ORIGIN_ID, &.{}) == null);
}

pub fn finalInternalGroupDoesNotRemainUnary() !void {
    var fixture: types.DeepFixture = undefined;
    initializeDeep(&fixture);
    var tree = try pack.pack(std.testing.allocator, fixture.Entries[0..constants.TAIL_RECORDS]);
    defer tree.deinit();
    try std.testing.expectEqual(constants.TAIL_NODES, tree.Nodes.len);
    try std.testing.expectEqual(constants.DEEP_DEPTH, tree.Header.Depth);
    const first = tree.Nodes[constants.TAIL_FIRST_PARENT];
    const last = tree.Nodes[constants.TAIL_LAST_PARENT];
    try std.testing.expect(first.Records.len > 1);
    try std.testing.expect(last.Records.len > 1);
    try std.testing.expectEqual(constants.TAIL_LEAVES, first.Records.len + last.Records.len);
}

pub fn identityBytesAreWidenedWithoutUnicodeDecoding() !void {
    var entry = constants.ORDERED_INPUT[3];
    entry.Identity = strings.BYTE_IDENTITY;
    const entries = [_]tool.types.catalog.Entry{entry};
    const spans = [_]afs.types.volume.SpanDescriptor{.{}};
    var tree = try pack.pack(std.testing.allocator, &entries);
    defer tree.deinit();
    var buffer: [constants.CELL_BYTES]u8 = @splat(constants.FILL_BYTE);
    try encode.encode(&tree, constants.FIRST_LEAF, &entries, &spans, &buffer);
    try std.testing.expectEqualSlices(u8, &constants.BYTE_IDENTITY_LE, buffer[constants.KEY_IDENTITY_OFFSET..][0..constants.BYTE_IDENTITY_LE.len]);
}

fn initializeDeep(fixture: *types.DeepFixture) void {
    for (&fixture.Names, 0..) |*name, index| {
        @memset(name, constants.NAME_BYTE);
        setSuffix(name, index * constants.GAP_STRIDE);
        const destination = fixture.Entries.len - index - 1;
        fixture.Entries[destination] = .{
            .ParentNodeId = constants.ORIGIN_ID,
            .NodeId = constants.FIRST_USER_ID + @as(u32, @intCast(index)),
            .Identity = name,
            .Kind = .Unit,
        };
        fixture.Spans[destination] = .{};
    }
}

fn setSuffix(name: []u8, value: usize) void {
    const start = name.len - constants.NAME_SUFFIX_BYTES;
    name[start] = constants.DIGIT_ZERO + @as(u8, @intCast(value / constants.DECIMAL_HUNDREDS));
    name[start + 1] = constants.DIGIT_ZERO + @as(u8, @intCast(value / constants.DECIMAL_TENS % constants.DECIMAL_TENS));
    name[start + 2] = constants.DIGIT_ZERO + @as(u8, @intCast(value % constants.DECIMAL_TENS));
}

fn findUnit(
    tree: *const tool.types.tree.TreePlan,
    entries: []const tool.types.catalog.Entry,
    spans: []const afs.types.volume.SpanDescriptor,
    parent: u32,
    identity: []const u16,
) !?afs.types.catalog.UnitRecord {
    var current = tree.Header.RootNode;
    var height = tree.Header.Depth;
    while (height > 0) : (height -= 1) {
        var buffer: [constants.CELL_BYTES]u8 = undefined;
        try encode.encode(tree, current, entries, spans, &buffer);
        try std.testing.expect(afs.btree.validate.catalogNode(&buffer));
        const descriptor = std.mem.bytesToValue(afs.types.btree.NodeDescriptor, buffer[0..constants.DESCRIPTOR_BYTES]);
        try std.testing.expectEqual(height, descriptor.Height);
        if (descriptor.isLeaf()) {
            const found = afs.btree.search.searchLeafForUnit(&buffer, constants.CELL_BYTES, descriptor.RecordCount, parent, identity) orelse return null;
            return found.*;
        }
        current = afs.btree.search.searchIndexNode(&buffer, constants.CELL_BYTES, descriptor.RecordCount, parent, identity) orelse return null;
    }
    return null;
}
