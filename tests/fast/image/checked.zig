//! Checked Shared AFS Constructor And Allocation Regressions

const std = @import("std");

const afs = @import("shared").afs;
const capacity = @import("tests").fast.image.constants.capacity;
const constants = @import("tests").fast.image.constants.checked;
const strings = @import("tests").fast.image.strings.capacity;

pub fn bitmapBackingMustCoverEveryCell() !void {
    var bitmap = [_]u8{constants.GUARD_BYTE} ** constants.SHORT_BITMAP_BYTES;
    const before = bitmap;
    try std.testing.expectError(error.InvalidBitmap, afs.types.allocation.AllocationMap.init(&bitmap, constants.TOTAL_CELLS, constants.FIRST_DATA_CELL));
    try std.testing.expectEqualSlices(u8, &before, &bitmap);
    try std.testing.expectError(error.InvalidBitmap, afs.types.allocation.AllocationMap.init(bitmap[0..0], 1, 0));
}

pub fn invalidInitialCursorDoesNotTouchBacking() !void {
    var bitmap = constants.INITIAL_BITMAP;
    try std.testing.expectError(error.InvalidCell, afs.types.allocation.AllocationMap.init(&bitmap, constants.TOTAL_CELLS, constants.INVALID_CURSOR));
    try std.testing.expectEqualSlices(u8, &constants.INITIAL_BITMAP, &bitmap);
    var full = try afs.types.allocation.AllocationMap.init(&bitmap, constants.TOTAL_CELLS, constants.TOTAL_CELLS);
    try std.testing.expectEqual(constants.TOTAL_CELLS, try full.allocateCells(0));
}

pub fn invalidReservationIsRejectedBeforeAnyBitChanges() !void {
    var bitmap = constants.INITIAL_BITMAP;
    var map = try afs.types.allocation.AllocationMap.init(&bitmap, constants.TOTAL_CELLS, constants.FIRST_DATA_CELL);
    try std.testing.expectError(error.InvalidCell, map.reserveRange(constants.INVALID_RANGE_START, constants.INVALID_RANGE_COUNT));
    try std.testing.expectEqualSlices(u8, &constants.INITIAL_BITMAP, &bitmap);
    try std.testing.expectEqual(constants.FIRST_DATA_CELL, map.NextFree);
    try std.testing.expectError(error.InvalidCell, map.reserveRange(std.math.maxInt(u32), 2));
    try std.testing.expectError(error.InvalidCell, map.reserveRange(constants.INVALID_CURSOR, 0));
    try map.reserveRange(constants.TOTAL_CELLS, 0);
    try std.testing.expectEqualSlices(u8, &constants.INITIAL_BITMAP, &bitmap);
}

pub fn allocationRejectsCorruptCursorAndWrappedDemand() !void {
    var bitmap = constants.INITIAL_BITMAP;
    var map = try afs.types.allocation.AllocationMap.init(&bitmap, constants.TOTAL_CELLS, constants.FIRST_DATA_CELL);
    map.NextFree = constants.INVALID_CURSOR;
    try std.testing.expectError(error.InvalidCell, map.allocateCells(0));
    try std.testing.expectEqual(constants.INVALID_CURSOR, map.NextFree);
    map.NextFree = std.math.maxInt(u32);
    try std.testing.expectError(error.InvalidCell, map.allocateCells(1));
    try std.testing.expectEqual(std.math.maxInt(u32), map.NextFree);
    map.NextFree = constants.FIRST_DATA_CELL;
    try std.testing.expectError(error.OutOfSpace, map.allocateCells(std.math.maxInt(u32)));
    try std.testing.expectEqual(constants.FIRST_DATA_CELL, map.NextFree);
    try std.testing.expectEqualSlices(u8, &constants.INITIAL_BITMAP, &bitmap);
}

pub fn occupiedBumpCursorDoesNotAliasAnAllocation() !void {
    try rejectOccupiedBumpSpan(constants.OCCUPIED_CURSOR_BITMAP);
}

pub fn occupiedInteriorDoesNotPartiallyClaimAFreePrefix() !void {
    try rejectOccupiedBumpSpan(constants.OCCUPIED_INTERIOR_BITMAP);
}

fn rejectOccupiedBumpSpan(initial: [constants.BITMAP_BYTES]u8) !void {
    var bitmap = initial;
    var map = try afs.types.allocation.AllocationMap.init(&bitmap, constants.TOTAL_CELLS, constants.FIRST_DATA_CELL);
    try std.testing.expectEqual(constants.OCCUPIED_FREE_CELLS, map.freeCount());
    try std.testing.expectEqual(constants.FIRST_DATA_CELL, try map.allocateCells(0));
    try std.testing.expectEqualSlices(u8, &initial, &bitmap);
    try std.testing.expectEqual(constants.FIRST_DATA_CELL, map.NextFree);
    try std.testing.expectError(error.OutOfSpace, map.allocateCells(constants.ALLOCATION_REQUEST_CELLS));
    try std.testing.expectEqualSlices(u8, &initial, &bitmap);
    try std.testing.expectEqual(constants.FIRST_DATA_CELL, map.NextFree);
    try std.testing.expectEqual(constants.OCCUPIED_FREE_CELLS, map.freeCount());
    try std.testing.expectEqual(constants.TOTAL_CELLS, map.TotalCells);
    try std.testing.expectEqual(constants.FIRST_DATA_CELL, try map.allocateCells(0));
    try std.testing.expectEqualSlices(u8, &initial, &bitmap);
    try std.testing.expectEqual(constants.FIRST_DATA_CELL, map.NextFree);
}

pub fn formerBitmapBoundarySupportsTheLastValidBit() !void {
    for (capacity.VOLUMES, constants.LAST_BYTE_MASKS) |expected, last_mask| {
        const bitmap_bytes: usize = expected.BitmapBytes;
        const guarded = try std.testing.allocator.alloc(u8, bitmap_bytes + 2 * constants.GUARD_BYTES);
        defer std.testing.allocator.free(guarded);
        @memset(guarded, constants.GUARD_BYTE);
        const bitmap = guarded[constants.GUARD_BYTES..][0..bitmap_bytes];
        @memset(bitmap, 0);
        const total_cells: u32 = @intCast(expected.TotalCells);
        var map = try afs.types.allocation.AllocationMap.init(bitmap, total_cells, 0);
        try std.testing.expectEqual(total_cells, map.freeCount());
        try map.reserveRange(total_cells - 1, 1);
        try std.testing.expectEqual(last_mask, bitmap[bitmap.len - 1]);
        try std.testing.expect(std.mem.allEqual(u8, bitmap[0 .. bitmap.len - 1], 0));
        try std.testing.expectEqual(total_cells - 1, map.freeCount());
        try std.testing.expect(map.isAllocated(total_cells));
        try std.testing.expect(std.mem.allEqual(u8, guarded[0..constants.GUARD_BYTES], constants.GUARD_BYTE));
        try std.testing.expect(std.mem.allEqual(u8, guarded[constants.GUARD_BYTES + bitmap_bytes ..], constants.GUARD_BYTE));
    }
}

pub fn keySizeRejectsUnrepresentableNamesBeforeArithmetic() !void {
    try std.testing.expectError(error.InvalidIdentity, afs.write.stack.indexKeySize(capacity.INVALID_NAME_BYTES));
    try std.testing.expectError(error.InvalidIdentity, afs.write.stack.indexKeySize(std.math.maxInt(usize)));
}

pub fn keyConstructorRejectsNamesInsteadOfTruncating() !void {
    for ([_][]const u8{ strings.INVALID_SLASH, strings.INVALID_BACKSLASH, strings.INVALID_NUL }) |identity| {
        try std.testing.expectError(error.InvalidIdentity, afs.write.stack.createIndexKey(capacity.ORIGIN_ID, identity));
    }
    const oversized = [_]u8{capacity.NAME_BYTE} ** capacity.INVALID_NAME_BYTES;
    try std.testing.expectError(error.InvalidIdentity, afs.write.stack.createIndexKey(capacity.ORIGIN_ID, &oversized));
}

pub fn cellCountsRejectZeroGeometryAndNarrowingOverflow() !void {
    try std.testing.expectError(error.InvalidCell, afs.write.unit.cellsNeeded(0, 0));
    try std.testing.expectError(error.InvalidCell, afs.write.unit.cellsNeeded(1, 0));
    try std.testing.expectError(error.Overflow, afs.write.unit.cellsNeeded(constants.MAXIMUM_CHANNEL_BYTES + 1, capacity.CELL_BYTES));
    try std.testing.expectError(error.Overflow, afs.write.unit.cellsNeeded(std.math.maxInt(u64), capacity.CELL_BYTES));
}

pub fn channelsRejectImpossibleSizesAndSpanOverflow() !void {
    try std.testing.expectError(error.InvalidSpan, afs.write.unit.createChannelInfo(capacity.CELL_BYTES + 1, constants.FIRST_DATA_CELL, 1, capacity.CELL_BYTES));
    try std.testing.expectError(error.InvalidSpan, afs.write.unit.createChannelInfo(1, constants.FIRST_DATA_CELL, 0, capacity.CELL_BYTES));
    try std.testing.expectError(error.InvalidCell, afs.write.unit.createChannelInfo(0, 0, 0, 0));
    try std.testing.expectError(error.Overflow, afs.write.unit.createChannelInfo(0, 0, capacity.UNREPRESENTABLE_U32, capacity.CELL_BYTES));
    try std.testing.expectError(error.Overflow, afs.write.unit.createChannelInfo(1, std.math.maxInt(u64), 1, capacity.CELL_BYTES));
}

pub fn representableConstructorEndpointsRemainSupported() !void {
    try std.testing.expectEqual(@as(u32, @intCast(capacity.MAXIMUM_U32)), try afs.write.unit.cellsNeeded(constants.MAXIMUM_CHANNEL_BYTES, capacity.CELL_BYTES));
    const channel = try afs.write.unit.createChannelInfo(constants.MAXIMUM_CHANNEL_BYTES, 0, capacity.MAXIMUM_U32, capacity.CELL_BYTES);
    try std.testing.expectEqual(constants.MAXIMUM_CHANNEL_BYTES, channel.LogicalSize);
    try std.testing.expectEqual(constants.MAXIMUM_CHANNEL_BYTES, channel.PhysicalSize);
    try std.testing.expectEqual(@as(u32, @intCast(capacity.MAXIMUM_U32)), channel.TotalCells);
    const empty = try afs.write.unit.createChannelInfo(0, constants.FIRST_DATA_CELL, 0, capacity.CELL_BYTES);
    try std.testing.expectEqualDeep(afs.types.volume.SpanDescriptor{}, empty.Spans[0]);
    const identity = [_]u8{capacity.NAME_BYTE} ** capacity.MAXIMUM_NAME_BYTES;
    const key = try afs.write.stack.createIndexKey(capacity.ORIGIN_ID, &identity);
    try std.testing.expectEqual(capacity.MAXIMUM_KEY_BYTES, key.KeyLength);
    try std.testing.expectEqual(capacity.MAXIMUM_NAME_BYTES, key.getIdentityLength());
    const bytes = try afs.write.stack.createIndexKey(capacity.ORIGIN_ID, strings.BYTE_IDENTITY);
    try std.testing.expectEqualSlices(u16, &[_]u16{ 0xc3, 0xa9 }, bytes.Identity[0..strings.BYTE_IDENTITY.len]);
    var backing: [0]u8 = .{};
    var map = try afs.types.allocation.AllocationMap.init(&backing, 0, 0);
    try std.testing.expectEqual(@as(u32, 0), try map.allocateCells(0));
    try map.reserveRange(0, 0);
}
