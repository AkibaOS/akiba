//! Active Image Lookup Through Production Shared AFS Readers

const std = @import("std");

const afs = @import("shared").afs;
const capacity = @import("tests").fast.toolchain.image.constants.capacity;
const io = @import("tests").fast.toolchain.image.io;
const strings = @import("tests").fast.toolchain.image.strings.emission;
const types = @import("tests").fast.types.image;

pub fn openImage(file: std.fs.File) !types.AFSImage {
    var bytes: [@sizeOf(afs.types.volume.VolumeHeader)]u8 = undefined;
    try io.readExact(file, capacity.PARTITION_START, &bytes);
    const header = std.mem.bytesToValue(afs.types.volume.VolumeHeader, &bytes);
    try std.testing.expect(header.isValid());
    try std.testing.expectEqual(capacity.CELL_BYTES, header.CellSize);
    try std.testing.expectEqual(capacity.CELL_BYTES, header.IndexNodeSize);
    try std.testing.expect(afs.read.bounds.spanFits(header.IndexSpan, header.TotalCells));
    try std.testing.expect(header.IndexTotalNodes <= header.IndexSpan.CellCount);
    return .{
        .Header = header,
        .Leaf = undefined,
        .Device = .{ .File = file, .PartitionStart = capacity.PARTITION_START, .CellSize = header.CellSize },
    };
}

pub fn treeHeader(image: *types.AFSImage) !afs.types.btree.records.HeaderRecord {
    const reader = io.reader(image);
    try reader.readCell(image.Header.IndexSpan.StartCell, &image.Leaf);
    const descriptor = std.mem.bytesToValue(afs.types.btree.records.NodeDescriptor, image.Leaf[0..capacity.DESCRIPTOR_BYTES]);
    try std.testing.expect(descriptor.isHeader());
    try std.testing.expectEqual(@as(u8, 0), descriptor.Height);
    try std.testing.expectEqual(@as(u16, 1), descriptor.RecordCount);
    try std.testing.expectEqual(@as(u32, 0), descriptor.ForwardLink);
    try std.testing.expectEqual(@as(u32, 0), descriptor.BackwardLink);
    return std.mem.bytesToValue(afs.types.btree.records.HeaderRecord, image.Leaf[capacity.DESCRIPTOR_BYTES..][0..@sizeOf(afs.types.btree.records.HeaderRecord)]);
}

pub fn readNode(image: *types.AFSImage, node_number: u32) !afs.types.btree.records.NodeDescriptor {
    try std.testing.expect(node_number != 0 and node_number < image.Header.IndexTotalNodes);
    try std.testing.expect(node_number < image.Header.IndexSpan.CellCount);
    const cell = try std.math.add(u64, image.Header.IndexSpan.StartCell, node_number);
    const reader = io.reader(image);
    try reader.readCell(cell, &image.Leaf);
    try std.testing.expect(afs.btree.validate.catalogNode(&image.Leaf));
    return std.mem.bytesToValue(afs.types.btree.records.NodeDescriptor, image.Leaf[0..capacity.DESCRIPTOR_BYTES]);
}

pub fn findRecord(comptime Record: type, image: *types.AFSImage, parent: u32, identity_bytes: []const u8) !?Record {
    if (identity_bytes.len > capacity.MAXIMUM_NAME_BYTES) return error.TestUnexpectedResult;
    var identity: [capacity.MAXIMUM_NAME_BYTES]u16 = undefined;
    for (identity_bytes, 0..) |byte, index| identity[index] = byte;
    const name = identity[0..identity_bytes.len];
    var node_number = image.Header.IndexRootNode;
    var depth = image.Header.IndexDepth;
    try std.testing.expect(depth != 0 and depth <= std.math.maxInt(u8));
    while (depth > 0) : (depth -= 1) {
        const descriptor = try readNode(image, node_number);
        try std.testing.expectEqual(depth, descriptor.Height);
        try std.testing.expectEqual(depth == 1, descriptor.isLeaf());
        if (descriptor.isLeaf()) {
            if (comptime Record == afs.types.catalog.UnitRecord) {
                const found = afs.btree.search.searchLeafForUnit(&image.Leaf, image.Header.IndexNodeSize, descriptor.RecordCount, parent, name) orelse return null;
                return found.*;
            } else if (comptime Record == afs.types.catalog.StackRecord) {
                const found = afs.btree.search.searchLeafForStack(&image.Leaf, image.Header.IndexNodeSize, descriptor.RecordCount, parent, name) orelse return null;
                return found.*;
            } else {
                @compileError(strings.UNSUPPORTED_RECORD);
            }
        }
        node_number = afs.btree.search.searchIndexNode(&image.Leaf, image.Header.IndexNodeSize, descriptor.RecordCount, parent, name) orelse return null;
    }
    return null;
}

pub fn expectLeafChain(image: *types.AFSImage) !void {
    var current = image.Header.IndexFirstLeaf;
    var previous: u32 = 0;
    var visited: u32 = 0;
    var records: u64 = 0;
    while (current != 0) {
        try std.testing.expect(visited < image.Header.IndexTotalNodes);
        const descriptor = try readNode(image, current);
        try std.testing.expect(descriptor.isLeaf());
        try std.testing.expectEqual(@as(u8, 1), descriptor.Height);
        try std.testing.expect(descriptor.RecordCount != 0);
        try std.testing.expectEqual(previous, descriptor.BackwardLink);
        records += descriptor.RecordCount;
        visited += 1;
        previous = current;
        current = descriptor.ForwardLink;
    }
    try std.testing.expectEqual(image.Header.IndexLastLeaf, previous);
    try std.testing.expectEqual(@as(u64, image.Header.IndexRecordCount), records);
}
