//! Pure AFS Volume And Disk Capacity Regressions

const std = @import("std");

const afs = @import("shared").afs;
const constants = @import("tests").fast.toolchain.image.constants.capacity;
const geometry = @import("mkafsdisk").image.geometry;
const tool = @import("mkafsdisk");

pub fn bitmapCoverageBoundary() !void {
    for (constants.VOLUMES) |expected| {
        const actual = try geometry.volume(expected.TotalCells, constants.EMPTY_TREE_NODES, constants.PAYLOAD_CELLS);
        try std.testing.expectEqual(@as(u32, @intCast(expected.TotalCells)), actual.TotalCells);
        try std.testing.expectEqual(expected.BitmapBytes, actual.BitmapBytes);
        try std.testing.expectEqual(expected.BitmapCells, actual.BitmapCells);
        try std.testing.expectEqual(constants.MAP_START, actual.AllocationMapStartCell);
        try std.testing.expectEqual(expected.BitmapCells * constants.CELL_BYTES, actual.AllocationMapSize);
        try std.testing.expectEqual(expected.IndexStartCell, actual.IndexStartCell);
        try std.testing.expectEqual(constants.EMPTY_TREE_NODES, actual.IndexCells);
        try std.testing.expectEqual(expected.DataStartCell, actual.DataStartCell);
        try std.testing.expectEqual(expected.UsedCells, actual.UsedCells);
        try std.testing.expectEqual(expected.FreeCells, actual.FreeCells);
    }
}

pub fn metadataAndPayloadMustFit() !void {
    const exact = try geometry.volume(constants.EXACT_VOLUME_CELLS, constants.EMPTY_TREE_NODES, constants.ONE_PAYLOAD_CELL);
    try std.testing.expectEqual(@as(u32, @intCast(constants.EXACT_VOLUME_CELLS)), exact.UsedCells);
    try std.testing.expectEqual(@as(u32, 0), exact.FreeCells);
    try std.testing.expectError(error.OutOfSpace, geometry.volume(constants.SHORT_VOLUME_CELLS, constants.EMPTY_TREE_NODES, constants.ONE_PAYLOAD_CELL));
    const metadata = try geometry.volume(constants.SHORT_VOLUME_CELLS, constants.EMPTY_TREE_NODES, 0);
    try std.testing.expectEqual(@as(u32, @intCast(constants.SHORT_VOLUME_CELLS)), metadata.UsedCells);
    try std.testing.expectError(error.OutOfSpace, geometry.volume(constants.SHORT_VOLUME_CELLS - 1, constants.EMPTY_TREE_NODES, 0));
    try std.testing.expectError(error.OutOfSpace, geometry.volume(constants.MAXIMUM_U32, constants.MAXIMUM_U32, 0));
}

pub fn spansAreAssignedInsideTheFrozenPayloadPlan() !void {
    var entries = [_]tool.types.catalog.entry.Entry{
        constants.ORDERED_INPUT[3],
        constants.ORDERED_INPUT[2],
        constants.ORDERED_INPUT[4],
        constants.ORDERED_INPUT[1],
    };
    entries[0].LogicalSize = constants.ONE_PAYLOAD_CELL;
    entries[2].Kind = .Stack;
    entries[3].LogicalSize = constants.CELL_BYTES + 1;
    const plan = try geometry.volume(constants.SPAN_TOTAL_CELLS, constants.EMPTY_TREE_NODES, constants.PAYLOAD_CELLS);
    const assigned = try geometry.spans(std.testing.allocator, &entries, plan);
    defer std.testing.allocator.free(assigned);
    try std.testing.expectEqual(entries.len, assigned.len);
    try std.testing.expectEqualDeep(afs.types.volume.SpanDescriptor{ .StartCell = constants.SPAN_DATA_START, .CellCount = 1 }, assigned[0]);
    try std.testing.expectEqualDeep(afs.types.volume.SpanDescriptor{}, assigned[1]);
    try std.testing.expectEqualDeep(afs.types.volume.SpanDescriptor{}, assigned[2]);
    try std.testing.expectEqualDeep(afs.types.volume.SpanDescriptor{ .StartCell = constants.SPAN_SECOND_START, .CellCount = 2 }, assigned[3]);
    try std.testing.expectEqual(constants.SPAN_FINAL_END, assigned[3].StartCell + assigned[3].CellCount);
    try std.testing.expectEqual(@as(u32, @intCast(constants.SPAN_FINAL_END)), plan.UsedCells);
    const insufficient = try geometry.volume(constants.SPAN_TOTAL_CELLS, constants.EMPTY_TREE_NODES, constants.PAYLOAD_CELLS - 1);
    try std.testing.expectError(error.OutOfSpace, geometry.spans(std.testing.allocator, &entries, insufficient));
}

pub fn unrepresentablePlansAreRejected() !void {
    try std.testing.expectError(error.InvalidGeometry, geometry.volume(0, constants.EMPTY_TREE_NODES, 0));
    try std.testing.expectError(error.InvalidGeometry, geometry.volume(constants.EXACT_VOLUME_CELLS, 0, 0));
    try std.testing.expectError(error.Overflow, geometry.volume(constants.UNREPRESENTABLE_U32, constants.EMPTY_TREE_NODES, 0));
    try std.testing.expectError(error.Overflow, geometry.volume(constants.MAXIMUM_U32, constants.UNREPRESENTABLE_U32, 0));
    try std.testing.expectError(error.Overflow, geometry.volume(constants.MAXIMUM_U32, constants.EMPTY_TREE_NODES, std.math.maxInt(u64)));
}

pub fn wideDiskGeometryAndProtectiveSaturation() !void {
    for (constants.DISKS) |expected| {
        const actual = try geometry.disk(expected.SizeMiB);
        try std.testing.expectEqual(expected.TotalSectors, actual.TotalSectors);
        try std.testing.expectEqual(expected.ProtectiveSectorCount, actual.ProtectiveSectorCount);
        try std.testing.expectEqual(expected.TotalCells, actual.TotalCells);
        try std.testing.expectEqual(expected.TotalSectors * constants.SECTOR_BYTES, actual.TotalBytes);
        try std.testing.expectEqual(constants.ESP_FIRST, actual.EspStartLBA);
        try std.testing.expectEqual(constants.ESP_LAST, actual.EspEndLBA);
        try std.testing.expectEqual(constants.AFS_FIRST, actual.AfsStartLBA);
        try std.testing.expectEqual(actual.TotalSectors - 1, actual.BackupHeaderLBA);
        try std.testing.expectEqual(actual.BackupHeaderLBA - constants.GPT_TABLE_SECTORS, actual.BackupEntriesLBA);
        try std.testing.expectEqual(actual.BackupEntriesLBA - 1, actual.AfsEndLBA);
        try std.testing.expectEqual(@as(u64, expected.TotalCells) * constants.CELL_BYTES + constants.TRAILING_BYTES, actual.PartitionSizeBytes);
    }
}

pub fn reciprocalGptLocations() !void {
    const actual = try geometry.disk(constants.DEFAULT_MIB);
    try std.testing.expectEqual(constants.DEFAULT_BYTES, actual.TotalBytes);
    try std.testing.expectEqual(constants.DEFAULT_SECTORS, actual.TotalSectors);
    try std.testing.expectEqual(constants.PRIMARY_HEADER, actual.PrimaryHeaderLBA);
    try std.testing.expectEqual(constants.PRIMARY_ENTRIES, actual.PrimaryEntriesLBA);
    try std.testing.expectEqual(constants.BACKUP_HEADER, actual.BackupHeaderLBA);
    try std.testing.expectEqual(constants.BACKUP_ENTRIES, actual.BackupEntriesLBA);
    try std.testing.expectEqual(constants.FIRST_USABLE, actual.FirstUsableLBA);
    try std.testing.expectEqual(constants.AFS_LAST, actual.LastUsableLBA);
    try std.testing.expectEqual(constants.AFS_LAST, actual.AfsEndLBA);
    try std.testing.expectEqual(constants.PARTITION_START, actual.PartitionStartByte);
    try std.testing.expectEqual(constants.PARTITION_BYTES, actual.PartitionSizeBytes);
}

pub fn unsupportedDiskGeometryIsRejected() !void {
    try std.testing.expectError(error.InvalidGeometry, geometry.disk(0));
    try std.testing.expectError(error.InvalidGeometry, geometry.disk(constants.BELOW_MINIMUM_MIB));
    try std.testing.expectError(error.Overflow, geometry.disk(constants.EXCESSIVE_MIB));
    try std.testing.expectError(error.Overflow, geometry.disk(std.math.maxInt(u32)));
}
