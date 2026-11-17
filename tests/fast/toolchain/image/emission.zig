//! Active AFS Writer Catalog Bitmap And Payload Regressions

const std = @import("std");

const afs = @import("shared").afs;
const capacity = @import("tests").fast.toolchain.image.constants.capacity;
const constants = @import("tests").fast.toolchain.image.constants.emission;
const fixture = @import("tests").fast.toolchain.image.fixture;
const inputs = @import("tests").constants.image;
const io = @import("tests").fast.toolchain.image.io;
const lookup = @import("tests").fast.toolchain.image.lookup;
const names = @import("tests").strings.image;
const strings = @import("tests").fast.toolchain.image.strings.emission;
const tool = @import("mkafsdisk");
const types = @import("tests").types.image;

pub fn moderateCatalogIsReadThroughProductionSearch() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    try fixture.addModerateUnits(temporary.dir);
    try tool.image.create.createDiskImage(std.testing.allocator, paths.Source, paths.Output, capacity.DEFAULT_MIB);
    const file = try temporary.dir.openFile(names.IMAGE_NAME, .{});
    defer file.close();
    var image = try lookup.openImage(file);
    try std.testing.expect(image.Header.IndexDepth > 1);
    try std.testing.expectEqual(constants.MODERATE_DEPTH, image.Header.IndexDepth);
    try std.testing.expectEqual(constants.MODERATE_NODES, image.Header.IndexTotalNodes);
    try std.testing.expectEqual(constants.MODERATE_TOTAL_UNITS, image.Header.UnitCount);
    try std.testing.expectEqual(constants.MODERATE_STACKS, image.Header.StackCount);
    try std.testing.expectEqual(constants.MODERATE_RECORDS, image.Header.IndexRecordCount);
    try expectSummary(&image);
    try lookup.expectLeafChain(&image);
    try expectAllocation(&image, 1, constants.MODERATE_USED_CELLS);
    var occupied: [constants.MODERATE_USED_CELLS]bool = @splat(false);
    const nested = (try lookup.findRecord(afs.types.catalog.StackRecord, &image, capacity.ORIGIN_ID, strings.NESTED_IDENTITY)) orelse return error.TestExpectedEqual;
    for (0..constants.MODERATE_UNITS) |index| {
        var identity: [constants.MODERATE_NAME_BYTES]u8 = undefined;
        fixture.identity(index, &identity);
        const unit = (try lookup.findRecord(afs.types.catalog.UnitRecord, &image, nested.NodeId, &identity)) orelse return error.TestExpectedEqual;
        const expected = fixture.payload(index);
        try expectUnit(&image, &unit, &expected, constants.MODERATE_DATA_START, &occupied);
        try std.testing.expect(try lookup.findRecord(afs.types.catalog.UnitRecord, &image, capacity.ORIGIN_ID, &identity) == null);
    }
    const boot = try bootloader(&image);
    try expectUnit(&image, &boot, &inputs.BOOTLOADER_BYTES, constants.MODERATE_DATA_START, &occupied);
    for (occupied[constants.MODERATE_DATA_START..]) |allocated| try std.testing.expect(allocated);
    try fixture.expectOwnedEntries(temporary.dir, true, true);
}

pub fn emittedDeepTreeUsesProductionSharedRouting() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    try fixture.addDeepUnits(temporary.dir);
    try tool.image.create.createDiskImage(std.testing.allocator, paths.Source, paths.Output, capacity.DEFAULT_MIB);
    const file = try temporary.dir.openFile(names.IMAGE_NAME, .{});
    defer file.close();
    var image = try lookup.openImage(file);
    try std.testing.expectEqual(constants.DEEP_DEPTH, image.Header.IndexDepth);
    try std.testing.expectEqual(constants.DEEP_NODES, image.Header.IndexTotalNodes);
    try std.testing.expect(image.Header.IndexTotalNodes > capacity.FORMER_INDEX_NODES);
    try std.testing.expectEqual(constants.DEEP_TOTAL_UNITS, image.Header.UnitCount);
    try std.testing.expectEqual(constants.MODERATE_STACKS, image.Header.StackCount);
    try std.testing.expectEqual(constants.DEEP_RECORDS, image.Header.IndexRecordCount);
    try expectSummary(&image);
    try lookup.expectLeafChain(&image);
    try expectAllocation(&image, 1, constants.DEEP_USED_CELLS);
    var occupied: [constants.DEEP_USED_CELLS]bool = @splat(false);
    const nested = (try lookup.findRecord(afs.types.catalog.StackRecord, &image, capacity.ORIGIN_ID, strings.NESTED_IDENTITY)) orelse return error.TestExpectedEqual;
    for (0..constants.DEEP_UNITS) |index| {
        var identity: [constants.DEEP_NAME_BYTES]u8 = undefined;
        fixture.identity(index * constants.DEEP_STRIDE, &identity);
        const unit = (try lookup.findRecord(afs.types.catalog.UnitRecord, &image, nested.NodeId, &identity)) orelse return error.TestExpectedEqual;
        const expected = fixture.payload(index);
        try expectUnit(&image, &unit, &expected, constants.DEEP_DATA_START, &occupied);
        try std.testing.expect(try lookup.findRecord(afs.types.catalog.UnitRecord, &image, capacity.ORIGIN_ID, &identity) == null);
        fixture.identity(index * constants.DEEP_STRIDE + 1, &identity);
        try std.testing.expect(try lookup.findRecord(afs.types.catalog.UnitRecord, &image, nested.NodeId, &identity) == null);
    }
    try std.testing.expect(try lookup.findRecord(afs.types.catalog.UnitRecord, &image, nested.NodeId, names.EMPTY_CONTENT) == null);
    const boot = try bootloader(&image);
    try expectUnit(&image, &boot, &inputs.BOOTLOADER_BYTES, constants.DEEP_DATA_START, &occupied);
    for (occupied[constants.DEEP_DATA_START..]) |allocated| try std.testing.expect(allocated);
    try fixture.expectOwnedEntries(temporary.dir, true, true);
}

pub fn emittedBitmapCoversCellsPastTheFormerThreshold() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    try tool.image.create.createDiskImage(std.testing.allocator, paths.Source, paths.Output, constants.BITMAP_IMAGE_MIB);
    const file = try temporary.dir.openFile(names.IMAGE_NAME, .{});
    defer file.close();
    var image = try lookup.openImage(file);
    try std.testing.expectEqual(constants.BITMAP_TOTAL_CELLS, image.Header.TotalCells);
    try std.testing.expectEqual(constants.BITMAP_INDEX_START, image.Header.IndexSpan.StartCell);
    try std.testing.expectEqual(@as(u64, capacity.EMPTY_TREE_NODES), image.Header.IndexSpan.CellCount);
    try std.testing.expectEqual(@as(u32, constants.BITMAP_BYTES), afs.write.allocate.bitmapSize(image.Header.TotalCells));
    try expectSummary(&image);
    try lookup.expectLeafChain(&image);
    try expectAllocation(&image, constants.BITMAP_CELLS, constants.BITMAP_USED_CELLS);
    var occupied: [constants.BITMAP_USED_CELLS]bool = @splat(false);
    const boot = try bootloader(&image);
    try expectUnit(&image, &boot, &inputs.BOOTLOADER_BYTES, constants.BITMAP_DATA_START, &occupied);
    for (occupied[constants.BITMAP_DATA_START..]) |allocated| try std.testing.expect(allocated);
    try fixture.expectOwnedEntries(temporary.dir, true, true);
}

pub fn nativeSpacedAndWideHostPathsRemainSupported() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.makeDir(strings.WIDE_ROOT);
    var root = try temporary.dir.openDir(strings.WIDE_ROOT, .{});
    defer root.close();
    var paths = try fixture.paths(std.testing.allocator, root);
    defer paths.deinit();
    try fixture.createSource(root, true);
    try fixture.writeSentinel(root);
    try tool.image.create.createDiskImage(std.testing.allocator, paths.Source, paths.Output, capacity.DEFAULT_MIB);
    const file = try root.openFile(names.IMAGE_NAME, .{});
    defer file.close();
    try std.testing.expectEqual(inputs.IMAGE_BYTES, try file.getEndPos());
    var image = try lookup.openImage(file);
    const unit = try bootloader(&image);
    const reader = io.reader(&image);
    var scratch: [capacity.CELL_BYTES]u8 = undefined;
    var bytes: [inputs.BOOTLOADER_BYTES.len]u8 = undefined;
    try std.testing.expectEqual(@as(u64, bytes.len), try afs.read.unit.readUnit(&reader, &unit, &bytes, &scratch));
    try std.testing.expectEqualSlices(u8, &inputs.BOOTLOADER_BYTES, &bytes);
    try fixture.expectOwnedEntries(root, true, true);
}

fn expectSummary(image: *types.AFSImage) !void {
    const header = try lookup.treeHeader(image);
    try std.testing.expectEqual(capacity.MAXIMUM_KEY_BYTES, header.MaxKeyLength);
    try std.testing.expectEqual(image.Header.IndexDepth, header.Depth);
    try std.testing.expectEqual(image.Header.IndexRootNode, header.RootNode);
    try std.testing.expectEqual(image.Header.IndexFirstLeaf, header.FirstLeafNode);
    try std.testing.expectEqual(image.Header.IndexLastLeaf, header.LastLeafNode);
    try std.testing.expectEqual(image.Header.IndexNodeSize, header.NodeSize);
    try std.testing.expectEqual(image.Header.IndexTotalNodes, header.TotalNodes);
    try std.testing.expectEqual(image.Header.IndexFreeNodes, header.FreeNodes);
    try std.testing.expectEqual(@as(u32, 0), header.FreeNodes);
    try std.testing.expectEqual(image.Header.IndexRecordCount, header.LeafRecordCount);
    try std.testing.expectEqual(@as(u64, image.Header.UnitCount) + image.Header.StackCount, @as(u64, header.LeafRecordCount));
    try std.testing.expectEqual(image.Header.IndexSpan.CellCount, @as(u64, header.TotalNodes));
    var primary: [capacity.CELL_BYTES]u8 = undefined;
    var alternate: [capacity.CELL_BYTES]u8 = undefined;
    try io.readExact(image.Device.File, image.Device.PartitionStart, &primary);
    try io.readExact(image.Device.File, image.Device.PartitionStart + capacity.CELL_BYTES, &alternate);
    try std.testing.expectEqualSlices(u8, &primary, &alternate);
}

fn expectAllocation(image: *types.AFSImage, map_cells: usize, used_cells: usize) !void {
    try std.testing.expectEqual(@as(u64, capacity.MAP_START), image.Header.AllocationMapSpan.StartCell);
    try std.testing.expectEqual(@as(u64, map_cells), image.Header.AllocationMapSpan.CellCount);
    try std.testing.expectEqual(@as(u32, @intCast(map_cells * capacity.CELL_BYTES)), image.Header.AllocationMapSize);
    try std.testing.expectEqual(@as(u64, capacity.MAP_START + map_cells), image.Header.IndexSpan.StartCell);
    const bitmap = try std.testing.allocator.alloc(u8, map_cells * capacity.CELL_BYTES);
    defer std.testing.allocator.free(bitmap);
    const reader = io.reader(image);
    try reader.readCells(image.Header.AllocationMapSpan.StartCell, bitmap);
    const data_start = try std.math.add(u64, image.Header.IndexSpan.StartCell, image.Header.IndexSpan.CellCount);
    const map = try afs.types.allocation.AllocationMap.init(bitmap, image.Header.TotalCells, @intCast(data_start));
    for (0..used_cells) |cell| try std.testing.expect(map.isAllocated(@intCast(cell)));
    try std.testing.expect(!map.isAllocated(@intCast(used_cells)));
    try std.testing.expect(!map.isAllocated(image.Header.TotalCells - 1));
    if (image.Header.TotalCells > constants.FORMER_UNCOVERED_CELL) try std.testing.expect(!map.isAllocated(constants.FORMER_UNCOVERED_CELL));
    try std.testing.expectEqual(image.Header.TotalCells - @as(u32, @intCast(used_cells)), image.Header.FreeCells);
    try std.testing.expectEqual(image.Header.FreeCells, map.freeCount());
    const bitmap_bytes: usize = afs.write.allocate.bitmapSize(image.Header.TotalCells);
    try std.testing.expectEqual(constants.BITMAP_LAST_BYTE, bitmap[bitmap_bytes - 1]);
    try std.testing.expect(std.mem.allEqual(u8, bitmap[bitmap_bytes..], constants.PADDING_BYTE));
}

fn bootloader(image: *types.AFSImage) !afs.types.catalog.UnitRecord {
    const efi = (try lookup.findRecord(afs.types.catalog.StackRecord, image, capacity.ORIGIN_ID, names.EFI_NAME)) orelse return error.TestExpectedEqual;
    const boot = (try lookup.findRecord(afs.types.catalog.StackRecord, image, efi.NodeId, names.BOOT_NAME)) orelse return error.TestExpectedEqual;
    return (try lookup.findRecord(afs.types.catalog.UnitRecord, image, boot.NodeId, names.BOOTLOADER_NAME)) orelse return error.TestExpectedEqual;
}

fn expectUnit(image: *types.AFSImage, unit: *const afs.types.catalog.UnitRecord, expected: []const u8, data_start: usize, occupied: []bool) !void {
    try std.testing.expectEqual(@as(u64, expected.len), unit.DataChannel.LogicalSize);
    try std.testing.expectEqual(@as(u32, 1), unit.DataChannel.TotalCells);
    try std.testing.expectEqual(@as(u64, capacity.CELL_BYTES), unit.DataChannel.PhysicalSize);
    const span = unit.DataChannel.Spans[0];
    try std.testing.expectEqual(@as(u64, 1), span.CellCount);
    try std.testing.expect(span.StartCell >= data_start and span.StartCell < occupied.len);
    try std.testing.expect(!occupied[@intCast(span.StartCell)]);
    occupied[@intCast(span.StartCell)] = true;
    const bytes = try std.testing.allocator.alloc(u8, expected.len);
    defer std.testing.allocator.free(bytes);
    var scratch: [capacity.CELL_BYTES]u8 = undefined;
    const reader = io.reader(image);
    try std.testing.expectEqual(@as(u64, expected.len), try afs.read.unit.readUnit(&reader, unit, bytes, &scratch));
    try std.testing.expectEqualSlices(u8, expected, bytes);
    try reader.readCell(span.StartCell, &scratch);
    try io.expectZeros(scratch[expected.len..]);
}
