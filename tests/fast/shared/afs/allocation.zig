//! AFS Allocation Accounting Checks

const std = @import("std");

const allocation = @import("shared").afs.types.allocation;
const errors = @import("shared").afs.errors.allocate;
const operations = @import("shared").afs.write.allocate;

pub fn bitmapByteCounts() !void {
    try std.testing.expectEqual(@as(u32, 0), operations.bitmapSize(0));
    try std.testing.expectEqual(@as(u32, 1), operations.bitmapSize(1));
    try std.testing.expectEqual(@as(u32, 1), operations.bitmapSize(8));
    try std.testing.expectEqual(@as(u32, 2), operations.bitmapSize(9));
    try std.testing.expectEqual(@as(u32, 3), operations.bitmapSize(19));
    try std.testing.expectEqual(@as(u32, 536870912), operations.bitmapSize(std.math.maxInt(u32)));
}

pub fn boundedBitmapMutations() !void {
    var bitmap = [_]u8{ 0x01, 0x80, 0xf8 };
    var map = allocation.AllocationMap.init(&bitmap, 19, 3);
    try std.testing.expectEqual(@as(u32, 17), map.freeCount());
    map.markAllocated(1);
    map.markAllocated(1);
    map.markFree(0);
    map.markFree(0);
    map.reserveRange(14, 5);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x02, 0xc0, 0xff }, &bitmap);
    try std.testing.expectEqual(@as(u32, 13), map.freeCount());
    try std.testing.expect(!map.isAllocated(0));
    try std.testing.expect(map.isAllocated(1));
    try std.testing.expect(map.isAllocated(18));
    map.markAllocated(19);
    map.markFree(19);
    map.markFree(std.math.maxInt(u32));
    try std.testing.expect(map.isAllocated(19));
    try std.testing.expect(map.isAllocated(std.math.maxInt(u32)));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x02, 0xc0, 0xff }, &bitmap);
    try std.testing.expectEqual(@as(u32, 3), map.NextFree);
}

pub fn bumpAllocatorAccounting() !void {
    var bitmap = [_]u8{ 0x07, 0x00, 0xf8 };
    var map = allocation.AllocationMap.init(&bitmap, 19, 3);
    try std.testing.expectEqual(@as(u32, 16), map.freeCount());
    try std.testing.expectEqual(@as(u32, 3), try map.allocateCells(0));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x07, 0x00, 0xf8 }, &bitmap);
    try std.testing.expectEqual(@as(u32, 3), try map.allocateCells(2));
    try std.testing.expectEqual(@as(u32, 5), map.NextFree);
    try std.testing.expectEqual(@as(u32, 14), map.freeCount());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x1f, 0x00, 0xf8 }, &bitmap);
    try std.testing.expectEqual(@as(u32, 5), try map.allocateCells(14));
    try std.testing.expectEqual(@as(u32, 19), map.NextFree);
    try std.testing.expectEqual(@as(u32, 0), map.freeCount());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xff, 0xff, 0xff }, &bitmap);
    try std.testing.expectEqual(@as(u32, 19), try map.allocateCells(0));
    try std.testing.expectError(errors.AllocationError.OutOfSpace, map.allocateCells(1));
    try std.testing.expectEqual(@as(u32, 19), map.NextFree);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xff, 0xff, 0xff }, &bitmap);
    map.markFree(4);
    try std.testing.expectEqual(@as(u32, 1), map.freeCount());
    try std.testing.expectEqual(@as(u32, 19), map.NextFree);
    try std.testing.expectError(errors.AllocationError.OutOfSpace, map.allocateCells(1));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xef, 0xff, 0xff }, &bitmap);
}
