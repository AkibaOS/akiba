//! AFS Catalog Tree Checks

const std = @import("std");

const constants = @import("tests").constants.storage;
const node = @import("shared").afs.btree.node;
const search = @import("shared").afs.btree.search;
const types = @import("shared").afs.types.btree;
const validate = @import("shared").afs.btree.validate;

pub fn nodeGeometryAndRecords() !void {
    try std.testing.expectEqual(@as(u64, 0), node.getNodeCell(0, 4096, 512));
    try std.testing.expectEqual(@as(u64, 0), node.getNodeCell(7, 4096, 512));
    try std.testing.expectEqual(@as(u64, 1), node.getNodeCell(8, 4096, 512));
    try std.testing.expectEqual(@as(u32, 3584), node.getNodeOffsetInCell(7, 4096, 512));
    try std.testing.expectEqual(@as(u32, 0), node.getNodeOffsetInCell(8, 4096, 512));
    var buffer = constants.TREE_LEAF;
    try std.testing.expect(validate.catalogNode(&buffer));
    try std.testing.expectEqual(@as(u16, 16), node.getRecordOffset(&buffer, constants.TREE_BYTES, 0));
    try std.testing.expectEqual(@as(u16, 122), node.getRecordOffset(&buffer, constants.TREE_BYTES, 1));
    try std.testing.expectEqual(@as(u16, 532), node.getRecordOffset(&buffer, constants.TREE_BYTES, 2));
    try std.testing.expectEqual(@intFromPtr(&buffer) + constants.SECOND_KEY_OFFSET, @intFromPtr(node.getRecordPointerConst(&buffer, constants.TREE_BYTES, 1)));
    const pointer = node.getRecordPointer(&buffer, constants.TREE_BYTES, 0);
    try std.testing.expectEqual(@intFromPtr(&buffer) + constants.FIRST_KEY_OFFSET, @intFromPtr(pointer));
    pointer[0] = 8;
    try std.testing.expectEqual(@as(u8, 8), buffer[constants.FIRST_KEY_OFFSET]);
}

pub fn nodeKinds() !void {
    var descriptor = types.NodeDescriptor{};
    try std.testing.expect(descriptor.isLeaf());
    try std.testing.expect(!descriptor.isIndex());
    descriptor.NodeType = 0;
    try std.testing.expect(descriptor.isIndex());
    try std.testing.expect(!descriptor.isLeaf());
    descriptor.NodeType = 1;
    try std.testing.expect(descriptor.isHeader());
    descriptor.NodeType = 2;
    try std.testing.expect(descriptor.isMap());
    descriptor.NodeType = 3;
    try std.testing.expect(!descriptor.isLeaf());
    try std.testing.expect(!descriptor.isIndex());
    try std.testing.expect(!descriptor.isHeader());
    try std.testing.expect(!descriptor.isMap());
}

pub fn independentlyEncodedNodes() !void {
    try std.testing.expectEqual(@as(usize, 1024), constants.TREE_LEAF.len);
    try std.testing.expectEqual(@as(usize, 64), constants.TREE_INDEX.len);
    try std.testing.expectEqual(@as(usize, 40), constants.TREE_THREAD.len);
    try std.testing.expect(validate.catalogNode(&constants.TREE_LEAF));
    try std.testing.expect(validate.catalogNode(&constants.TREE_INDEX));
    try std.testing.expect(validate.catalogNode(&constants.TREE_THREAD));
    var empty = constants.THREAD_DESCRIPTOR;
    empty[constants.NODE_COUNT_OFFSET] = 0;
    try std.testing.expect(validate.catalogNode(&empty));
}

pub fn malformedDescriptors() !void {
    try std.testing.expect(!validate.catalogNode(constants.TREE_LEAF[0 .. constants.FIRST_KEY_OFFSET - 1]));
    try std.testing.expect(!validate.catalogNode(&.{}));
    try std.testing.expect(!validate.catalogNode(&([_]u8{0} ** 65537)));
    var buffer = constants.TREE_LEAF;
    buffer[constants.NODE_KIND_OFFSET] = 1;
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer[constants.NODE_KIND_OFFSET] = 2;
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer[constants.NODE_KIND_OFFSET] = 0xff;
    std.mem.writeInt(u16, buffer[constants.NODE_COUNT_OFFSET..][0..@sizeOf(u16)], 0xffff, .little);
    try std.testing.expect(!validate.catalogNode(&buffer));
}

pub fn malformedOffsets() !void {
    var buffer = constants.TREE_LEAF;
    std.mem.writeInt(u16, buffer[constants.LEAF_TABLE_OFFSET + 4 ..][0..@sizeOf(u16)], 15, .little);
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer = constants.TREE_LEAF;
    std.mem.writeInt(u16, buffer[constants.LEAF_TABLE_OFFSET + 2 ..][0..@sizeOf(u16)], 16, .little);
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer = constants.TREE_LEAF;
    std.mem.writeInt(u16, buffer[constants.LEAF_TABLE_OFFSET..][0..@sizeOf(u16)], 121, .little);
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer = constants.TREE_LEAF;
    std.mem.writeInt(u16, buffer[constants.LEAF_TABLE_OFFSET..][0..@sizeOf(u16)], 1019, .little);
    try std.testing.expect(!validate.catalogNode(&buffer));
}

pub fn malformedKeys() !void {
    var buffer = constants.TREE_LEAF;
    buffer[constants.FIRST_KEY_OFFSET] = 7;
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer[constants.FIRST_KEY_OFFSET] = 9;
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer[constants.FIRST_KEY_OFFSET] = 108;
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer = constants.TREE_LEAF;
    buffer[constants.NODE_KIND_OFFSET] = 0;
    buffer[constants.NODE_COUNT_OFFSET] = 1;
    std.mem.writeInt(u16, buffer[constants.FIRST_KEY_OFFSET..][0..@sizeOf(u16)], 522, .little);
    try std.testing.expect(!validate.catalogNode(&buffer));
    var index = constants.TREE_INDEX;
    index[constants.FIRST_KEY_OFFSET] = 14;
    try std.testing.expect(!validate.catalogNode(&index));
}

pub fn malformedPayloads() !void {
    var buffer = constants.TREE_LEAF;
    buffer[constants.FIRST_PAYLOAD_OFFSET] = 99;
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer = constants.TREE_LEAF;
    std.mem.writeInt(u16, buffer[constants.LEAF_TABLE_OFFSET + 2 ..][0..@sizeOf(u16)], 121, .little);
    try std.testing.expect(!validate.catalogNode(&buffer));
    buffer = constants.TREE_LEAF;
    std.mem.writeInt(u16, buffer[constants.LEAF_TABLE_OFFSET..][0..@sizeOf(u16)], 531, .little);
    try std.testing.expect(!validate.catalogNode(&buffer));
    try std.testing.expect(!validate.catalogNode(&constants.TREE_SHORT_THREAD));
    var thread = constants.TREE_THREAD;
    thread[constants.THREAD_LENGTH_OFFSET] = 3;
    try std.testing.expect(!validate.catalogNode(&thread));
    std.mem.writeInt(u16, thread[constants.THREAD_LENGTH_OFFSET..][0..@sizeOf(u16)], 257, .little);
    try std.testing.expect(!validate.catalogNode(&thread));
    thread = constants.TREE_THREAD;
    thread[constants.THREAD_PAYLOAD_OFFSET] = 0;
    try std.testing.expect(!validate.catalogNode(&thread));
}

pub fn keyOrdering() !void {
    const encoded = [_]u8{ 12, 0, 0, 0, 7, 0, 0, 0, 'A', 0, 'B', 0 };
    const key: *align(1) const types.IndexKey = @ptrCast(&encoded);
    try std.testing.expectEqual(@as(i32, -1), search.compareKeys(6, &.{'Z'}, key));
    try std.testing.expectEqual(@as(i32, 1), search.compareKeys(8, &.{}, key));
    try std.testing.expectEqual(@as(i32, -1), search.compareKeys(7, &.{}, key));
    try std.testing.expectEqual(@as(i32, -1), search.compareKeys(7, &.{'A'}, key));
    try std.testing.expectEqual(@as(i32, 0), search.compareKeys(7, &.{ 'A', 'B' }, key));
    try std.testing.expectEqual(@as(i32, 1), search.compareKeys(7, &.{ 'A', 'B', 'C' }, key));
    try std.testing.expectEqual(@as(i32, -1), search.compareKeys(7, &.{ 'A', 'A' }, key));
    try std.testing.expectEqual(@as(i32, 1), search.compareKeys(7, &.{ 'A', 'C' }, key));
    try std.testing.expectEqual(@as(i32, 1), search.compareKeys(7, &.{'a'}, key));
    try std.testing.expectEqual(@as(i32, 1), search.compareKeys(7, &.{0x672c}, key));
}

pub fn leafLookup() !void {
    const buffer = constants.TREE_LEAF;
    try std.testing.expect(validate.catalogNode(&buffer));
    const stack = search.searchLeafForStack(&buffer, buffer.len, 3, 7, &.{'A'}).?;
    const unit = search.searchLeafForUnit(&buffer, buffer.len, 3, 7, &.{'B'}).?;
    const thread = search.searchLeafForThread(&buffer, buffer.len, 3, 34, &.{}).?.*;
    try std.testing.expectEqual(@as(u32, 33), stack.NodeId);
    try std.testing.expectEqual(@as(u32, 34), unit.NodeId);
    try std.testing.expectEqual(@as(u32, 7), thread.ParentNodeId);
    try std.testing.expectEqual(@as(u16, 4), thread.RecordType);
    try std.testing.expectEqualSlices(u16, &[_]u16{ 0x672c, 'B' }, thread.getIdentity());
    try std.testing.expect(search.searchLeafForUnit(&buffer, buffer.len, 3, 7, &.{'A'}) == null);
    try std.testing.expect(search.searchLeafForStack(&buffer, buffer.len, 3, 7, &.{'B'}) == null);
    try std.testing.expect(search.searchLeafForUnit(&buffer, buffer.len, 3, 8, &.{'B'}) == null);
    try std.testing.expect(search.searchLeafForUnit(&buffer, buffer.len, 3, 7, &.{'b'}) == null);
    try std.testing.expect(search.searchLeafForThread(&buffer, buffer.len, 3, 34, &.{'B'}) == null);
    var alternate = constants.TREE_THREAD;
    alternate[constants.THREAD_PAYLOAD_OFFSET] = 3;
    try std.testing.expect(validate.catalogNode(&alternate));
    try std.testing.expectEqual(@as(u16, 3), search.searchLeafForThread(&alternate, alternate.len, 1, 34, &.{}).?.RecordType);
}

pub fn indexLookup() !void {
    const buffer = constants.TREE_INDEX;
    try std.testing.expect(validate.catalogNode(&buffer));
    try std.testing.expectEqual(@as(?u32, constants.FIRST_INDEX_CHILD), search.searchIndexNode(&buffer, buffer.len, 2, 6, &.{'Z'}));
    try std.testing.expectEqual(@as(?u32, constants.FIRST_INDEX_CHILD), search.searchIndexNode(&buffer, buffer.len, 2, 7, &.{}));
    try std.testing.expectEqual(@as(?u32, constants.FIRST_INDEX_CHILD), search.searchIndexNode(&buffer, buffer.len, 2, 7, &.{'A'}));
    try std.testing.expectEqual(@as(?u32, constants.SECOND_INDEX_CHILD), search.searchIndexNode(&buffer, buffer.len, 2, 7, &.{'B'}));
    try std.testing.expectEqual(@as(?u32, constants.SECOND_INDEX_CHILD), search.searchIndexNode(&buffer, buffer.len, 2, 7, &.{'C'}));
    try std.testing.expectEqual(@as(?u32, constants.SECOND_INDEX_CHILD), search.searchIndexNode(&buffer, buffer.len, 2, 7, &.{'D'}));
    try std.testing.expectEqual(@as(?u32, constants.SECOND_INDEX_CHILD), search.searchIndexNode(&buffer, buffer.len, 2, 8, &.{}));
    var empty = constants.TREE_INDEX;
    empty[constants.NODE_COUNT_OFFSET] = 0;
    try std.testing.expect(validate.catalogNode(&empty));
    try std.testing.expectEqual(@as(?u32, null), search.searchIndexNode(&empty, empty.len, 0, 7, &.{'A'}));
}
