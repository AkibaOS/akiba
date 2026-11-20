//! AFS Metadata Catalog And Payload Image Integration Checks

const std = @import("std");

const afs = @import("shared").afs;
const constants = @import("tests").fast.constants.image.fixtures;
const io = @import("tests").fast.image.io;
const strings = @import("tests").fast.strings.image.witnesses;
const types = @import("tests").fast.types.image.fixtures;

const AFSImage = types.AFSImage;
const NodeDescriptor = afs.types.btree.records.NodeDescriptor;
const UnitRecord = afs.types.catalog.UnitRecord;

pub fn metadataAndAllocation(file: std.fs.File) !AFSImage {
    var image: AFSImage = undefined;
    image.Device = .{
        .File = file,
        .PartitionStart = constants.AFS_FIRST_LBA * constants.SECTOR_BYTES,
        .CellSize = constants.CELL_BYTES,
    };
    var primary: [constants.CELL_BYTES]u8 = undefined;
    var alternate: [constants.CELL_BYTES]u8 = undefined;
    try io.readExact(file, image.Device.PartitionStart, &primary);
    @memcpy(std.mem.asBytes(&image.Header), primary[0..@sizeOf(afs.types.volume.VolumeHeader)]);
    try std.testing.expect(image.Header.isValid());
    try std.testing.expectEqual(constants.CELL_BYTES, image.Header.CellSize);
    try std.testing.expectEqual(constants.AFS_TOTAL_CELLS, image.Header.TotalCells);
    try std.testing.expectEqual(constants.UNIT_COUNT, image.Header.UnitCount);
    try std.testing.expectEqual(constants.STACK_COUNT, image.Header.StackCount);
    try std.testing.expectEqual(constants.NEXT_NODE_ID, image.Header.NextNodeId);
    try std.testing.expectEqual(constants.AFS_TOTAL_CELLS - constants.AFS_USED_CELLS, image.Header.FreeCells);
    try std.testing.expectEqual(@as(u32, 1), image.Header.WriteCount);
    try std.testing.expectEqual(constants.UNIT_COUNT + constants.STACK_COUNT, image.Header.IndexRecordCount);
    try std.testing.expectEqual(@as(u64, 2), image.Header.AllocationMapSpan.StartCell);
    try std.testing.expectEqual(@as(u64, 1), image.Header.AllocationMapSpan.CellCount);
    try std.testing.expectEqual(constants.CELL_BYTES, image.Header.AllocationMapSize);
    try std.testing.expectEqual(@as(u64, 3), image.Header.IndexSpan.StartCell);
    try std.testing.expectEqual(@as(u64, 2), image.Header.IndexSpan.CellCount);
    try std.testing.expectEqual(constants.CELL_BYTES, image.Header.IndexNodeSize);
    try std.testing.expectEqual(@as(u32, 2), image.Header.IndexTotalNodes);
    try std.testing.expectEqual(@as(u32, 0), image.Header.IndexFreeNodes);
    try std.testing.expectEqual(@as(u32, 1), image.Header.IndexRootNode);
    try std.testing.expectEqual(@as(u32, 1), image.Header.IndexFirstLeaf);
    try std.testing.expectEqual(@as(u32, 1), image.Header.IndexLastLeaf);
    try std.testing.expectEqual(@as(u16, 1), image.Header.IndexDepth);
    try io.readExact(file, image.Device.PartitionStart + constants.CELL_BYTES, &alternate);
    try std.testing.expectEqualSlices(u8, &primary, &alternate);
    const reader = io.reader(&image);
    var bitmap: [constants.CELL_BYTES]u8 = undefined;
    try reader.readCell(image.Header.AllocationMapSpan.StartCell, &bitmap);
    const map = try afs.types.allocation.AllocationMap.init(&bitmap, image.Header.TotalCells, constants.AFS_DATA_START);
    for (0..constants.AFS_USED_CELLS) |cell| try std.testing.expect(map.isAllocated(@intCast(cell)));
    try std.testing.expect(!map.isAllocated(constants.AFS_USED_CELLS));
    try std.testing.expect(!map.isAllocated(image.Header.TotalCells - 1));
    try std.testing.expectEqual(image.Header.FreeCells, map.freeCount());
    try reader.readCell(image.Header.IndexSpan.StartCell + image.Header.IndexRootNode, &image.Leaf);
    try std.testing.expect(afs.btree.validate.catalogNode(&image.Leaf));
    const descriptor = std.mem.bytesToValue(NodeDescriptor, image.Leaf[0..@sizeOf(NodeDescriptor)]);
    try std.testing.expect(descriptor.isLeaf());
    try std.testing.expectEqual(@as(u8, 1), descriptor.Height);
    try std.testing.expectEqual(@as(u16, constants.UNIT_COUNT + constants.STACK_COUNT), descriptor.RecordCount);
    return image;
}

pub fn catalogLookupAndReadback(image: *AFSImage) !void {
    const origin = try stackNode(image, afs.constants.nodes.ORIGIN, &strings.EMPTY_IDENTITY);
    try std.testing.expectEqual(afs.constants.nodes.ORIGIN_STACK, origin);
    const efi = try stackNode(image, origin, &strings.EFI_IDENTITY);
    const boot = try stackNode(image, efi, &strings.BOOT_IDENTITY);
    const docs = try stackNode(image, origin, &strings.DOCS_IDENTITY);
    try std.testing.expect(efi != boot and efi != docs and boot != docs);
    var occupied: [constants.AFS_USED_CELLS]bool = @splat(false);
    try expectUnit(image, origin, &strings.TINY_IDENTITY, strings.TINY_CONTENT, &occupied);
    try expectUnit(image, origin, &strings.CROSS_IDENTITY, &constants.CROSS_BYTES, &occupied);
    try expectUnit(image, origin, &strings.EMPTY_UNIT_IDENTITY, strings.EMPTY_CONTENT, &occupied);
    try expectUnit(image, boot, &strings.BOOTLOADER_IDENTITY, &constants.BOOTLOADER_BYTES, &occupied);
    try expectUnit(image, docs, &strings.NOTE_IDENTITY, strings.NOTE_CONTENT, &occupied);
    for (occupied[constants.AFS_DATA_START..]) |allocated| try std.testing.expect(allocated);
    const descriptor: *align(1) const NodeDescriptor = @ptrCast(&image.Leaf);
    try std.testing.expect(afs.btree.search.searchLeafForUnit(&image.Leaf, image.Header.IndexNodeSize, descriptor.RecordCount, origin, &strings.HIDDEN_IDENTITY) == null);
    try std.testing.expect(afs.btree.search.searchLeafForUnit(&image.Leaf, image.Header.IndexNodeSize, descriptor.RecordCount, docs, &strings.TINY_IDENTITY) == null);
    try std.testing.expect(afs.btree.search.searchLeafForUnit(&image.Leaf, image.Header.IndexNodeSize, descriptor.RecordCount, origin, &strings.NOTE_IDENTITY) == null);
}

fn stackNode(image: *const AFSImage, parent: u32, identity: []const u16) !u32 {
    const descriptor: *align(1) const NodeDescriptor = @ptrCast(&image.Leaf);
    const found = afs.btree.search.searchLeafForStack(&image.Leaf, image.Header.IndexNodeSize, descriptor.RecordCount, parent, identity);
    try std.testing.expect(found != null);
    return found.?.NodeId;
}

fn expectUnit(image: *AFSImage, parent: u32, identity: []const u16, expected: []const u8, occupied: *[constants.AFS_USED_CELLS]bool) !void {
    const descriptor: *align(1) const NodeDescriptor = @ptrCast(&image.Leaf);
    const found = afs.btree.search.searchLeafForUnit(&image.Leaf, image.Header.IndexNodeSize, descriptor.RecordCount, parent, identity);
    try std.testing.expect(found != null);
    const unit: UnitRecord = found.?.*;
    try std.testing.expectEqual(@as(u64, expected.len), unit.DataChannel.LogicalSize);
    const cells: u32 = if (expected.len == 0) 0 else @intCast(1 + (expected.len - 1) / constants.CELL_BYTES);
    try std.testing.expectEqual(cells, unit.DataChannel.TotalCells);
    try std.testing.expectEqual(@as(u64, cells) * constants.CELL_BYTES, unit.DataChannel.PhysicalSize);
    try std.testing.expectEqual(constants.CELL_BYTES, unit.DataChannel.ClumpSize);
    for (unit.DataChannel.Spans[1..]) |span| try std.testing.expectEqualDeep(afs.types.volume.SpanDescriptor{}, span);
    if (cells == 0) {
        try std.testing.expectEqualDeep(afs.types.volume.SpanDescriptor{}, unit.DataChannel.Spans[0]);
    } else {
        const span = unit.DataChannel.Spans[0];
        try std.testing.expectEqual(@as(u64, cells), span.CellCount);
        try std.testing.expect(span.StartCell >= constants.AFS_DATA_START and span.endCell() <= constants.AFS_USED_CELLS);
        for (@as(usize, @intCast(span.StartCell))..@as(usize, @intCast(span.endCell()))) |cell| {
            try std.testing.expect(!occupied[cell]);
            occupied[cell] = true;
        }
    }
    const reader = io.reader(image);
    var scratch: [constants.CELL_BYTES]u8 = undefined;
    var guarded: [constants.CROSS_BYTES.len + 2 * constants.GUARD_BYTES]u8 = @splat(constants.GUARD_BYTE);
    const destination = guarded[constants.GUARD_BYTES..][0..expected.len];
    try std.testing.expectEqual(@as(u64, expected.len), try afs.read.unit.readUnit(&reader, &unit, destination, &scratch));
    try std.testing.expectEqualSlices(u8, expected, destination);
    for (guarded[0..constants.GUARD_BYTES]) |byte| try std.testing.expectEqual(constants.GUARD_BYTE, byte);
    for (guarded[constants.GUARD_BYTES + expected.len ..]) |byte| try std.testing.expectEqual(constants.GUARD_BYTE, byte);
    if (cells > 0 and expected.len % constants.CELL_BYTES != 0) {
        const last_cell = unit.DataChannel.Spans[0].endCell() - 1;
        try reader.readCell(last_cell, &scratch);
        try io.expectZeros(scratch[expected.len % constants.CELL_BYTES ..]);
    }
}
