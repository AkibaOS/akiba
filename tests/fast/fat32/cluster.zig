//! FAT32 Cluster Helper Checks

const std = @import("std");

const errors = @import("shared").fat32.errors.cluster;
const operations = @import("shared").fat32.read.cluster;

pub fn classificationAndParsing() !void {
    try std.testing.expect(!operations.isValidCluster(0));
    try std.testing.expect(!operations.isValidCluster(1));
    try std.testing.expect(operations.isValidCluster(2));
    try std.testing.expect(operations.isValidCluster(0x0ffffff6));
    try std.testing.expect(!operations.isValidCluster(0x0ffffff7));
    try std.testing.expect(!operations.isValidCluster(0x0ffffff8));
    try std.testing.expect(!operations.isValidCluster(0xf0000002));
    try std.testing.expect(!operations.isEndOfChain(0x0ffffff7));
    try std.testing.expect(operations.isEndOfChain(0x0ffffff8));
    try std.testing.expect(operations.isEndOfChain(0xafffffff));
    try std.testing.expectEqual(@as(?u32, 2), try operations.parseFatEntry(0xf0000002));
    try std.testing.expectEqual(@as(?u32, 0x0ffffff6), try operations.parseFatEntry(0x0ffffff6));
    try std.testing.expectEqual(@as(?u32, null), try operations.parseFatEntry(0x0ffffff8));
    try std.testing.expectEqual(@as(?u32, null), try operations.parseFatEntry(0xffffffff));
    try std.testing.expectError(errors.ClusterError.BadCluster, operations.parseFatEntry(0xaffffff7));
    try std.testing.expectError(errors.ClusterError.InvalidCluster, operations.parseFatEntry(0));
    try std.testing.expectError(errors.ClusterError.InvalidCluster, operations.parseFatEntry(0xf0000001));
}

pub fn positionsAndAddresses() !void {
    const before = operations.getFatPosition(127, 512);
    try std.testing.expectEqual(@as(u32, 0), before.Sector);
    try std.testing.expectEqual(@as(u32, 508), before.Offset);
    const boundary = operations.getFatPosition(128, 512);
    try std.testing.expectEqual(@as(u32, 1), boundary.Sector);
    try std.testing.expectEqual(@as(u32, 0), boundary.Offset);
    const wide = operations.getFatPosition(1025, 4096);
    try std.testing.expectEqual(@as(u32, 1), wide.Sector);
    try std.testing.expectEqual(@as(u32, 4), wide.Offset);
    try std.testing.expectEqual(@as(u64, 2048), operations.clusterToLba(2, 2048, 8));
    try std.testing.expectEqual(@as(u64, 2056), operations.clusterToLba(3, 2048, 8));
    try std.testing.expectEqual(@as(u64, 2104), operations.clusterToLba(9, 2048, 8));
}
