//! AFS Fast Checks

const std = @import("std");

const bounds = @import("shared").afs.read.bounds;
const sizes = @import("shared").afs.constants.sizes;
const volume = @import("shared").afs.types.volume;

pub fn spanBounds() !void {
    try std.testing.expect(!bounds.spanFits(.{}, 64));
    try std.testing.expect(!bounds.spanFits(.{ .StartCell = 0, .CellCount = 1 }, 0));
    try std.testing.expect(bounds.spanFits(.{ .StartCell = 0, .CellCount = 64 }, 64));
    try std.testing.expect(bounds.spanFits(.{ .StartCell = 63, .CellCount = 1 }, 64));
    try std.testing.expect(!bounds.spanFits(.{ .StartCell = 0, .CellCount = 65 }, 64));
    try std.testing.expect(!bounds.spanFits(.{ .StartCell = 63, .CellCount = 2 }, 64));
    try std.testing.expect(!bounds.spanFits(.{ .StartCell = 64, .CellCount = 1 }, 64));
    try std.testing.expect(!bounds.spanFits(.{ .StartCell = 65, .CellCount = 1 }, 64));
}

pub fn spanOverflow() !void {
    const TOTAL_CELLS = std.math.maxInt(u64);

    try std.testing.expect(!bounds.spanFits(.{ .StartCell = TOTAL_CELLS - 3, .CellCount = 8 }, TOTAL_CELLS));
    try std.testing.expect(!bounds.spanFits(.{ .StartCell = 1, .CellCount = TOTAL_CELLS }, TOTAL_CELLS));
    try std.testing.expect(!bounds.spanFits(.{ .StartCell = TOTAL_CELLS, .CellCount = 1 }, TOTAL_CELLS));
    try std.testing.expect(bounds.spanFits(.{ .StartCell = TOTAL_CELLS - 1, .CellCount = 1 }, TOTAL_CELLS));
    try std.testing.expect(bounds.spanFits(.{ .StartCell = 0, .CellCount = TOTAL_CELLS }, TOTAL_CELLS));
}

pub fn inclusiveEndpoints() !void {
    try std.testing.expectEqual(@as(?u64, 2048), bounds.cellLBA(2048, 2079, 512, 4096, 0, 4096));
    try std.testing.expectEqual(@as(?u64, 2072), bounds.cellLBA(2048, 2079, 512, 4096, 3, 4096));
    try std.testing.expectEqual(@as(?u64, 2064), bounds.cellLBA(2048, 2079, 512, 4096, 2, 512));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2079, 512, 4096, 4, 512));
    try std.testing.expectEqual(@as(?u64, 2048), bounds.cellLBA(2048, 2048, 512, 512, 0, 512));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2048, 512, 512, 1, 512));
}

pub fn invalidGeometry() !void {
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(0, 31, 512, 4096, 0, 4096));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2047, 512, 4096, 0, 4096));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2079, 0, 4096, 0, 4096));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2079, 512, 0, 0, 4096));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2079, 512, 256, 0, 512));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2079, 512, 4097, 0, 4096));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2079, 512, 4096, 0, 0));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2079, 512, 4096, 0, 513));
}

pub fn truncatedReads() !void {
    try std.testing.expectEqual(@as(?u64, 2064), bounds.cellLBA(2048, 2078, 512, 4096, 2, 4096));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2078, 512, 4096, 3, 4096));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2054, 512, 4096, 0, 4096));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2079, 512, 4096, 3, 4608));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(2048, 2079, 512, 4096, 0, 16896));
    try std.testing.expectEqual(@as(?u64, 2048), bounds.cellLBA(2048, 2079, 512, 4096, 0, 16384));
}

pub fn largeOffsets() !void {
    const LAST_LBA = std.math.maxInt(u64);

    try std.testing.expectEqual(@as(?u64, LAST_LBA - 7), bounds.cellLBA(LAST_LBA - 15, LAST_LBA, 512, 4096, 1, 4096));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(LAST_LBA - 15, LAST_LBA, 512, 4096, 2, 512));
    try std.testing.expectEqual(@as(?u64, null), bounds.cellLBA(LAST_LBA - 15, LAST_LBA, 512, 4096, LAST_LBA, 512));
    try std.testing.expectEqual(@as(?u64, 1), bounds.cellLBA(1, LAST_LBA, 512, 4096, 0, 4096));
    try std.testing.expectEqual(@as(?u64, LAST_LBA), bounds.cellLBA(LAST_LBA, LAST_LBA, 512, 512, 0, 512));
}

pub fn signatureAndVersion() !void {
    var header: volume.VolumeHeader = .{};

    try std.testing.expect(header.isValid());
    header.Signature ^= 1;
    try std.testing.expect(!header.isValid());
    header.Signature ^= 1;
    header.Version ^= 1;
    try std.testing.expect(!header.isValid());
    header.Version ^= 1;
    try std.testing.expect(header.isValid());
}

pub fn cellSizeBoundaries() !void {
    var header: volume.VolumeHeader = .{ .CellSize = sizes.MINIMUM_CELL_SIZE };

    try std.testing.expect(header.isValid());
    header.CellSize = sizes.MAXIMUM_CELL_SIZE;
    try std.testing.expect(header.isValid());
    header.CellSize = sizes.MINIMUM_CELL_SIZE - 1;
    try std.testing.expect(!header.isValid());
    header.CellSize = sizes.MAXIMUM_CELL_SIZE + 1;
    try std.testing.expect(!header.isValid());
}
