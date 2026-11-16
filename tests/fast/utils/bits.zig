//! Bitmap Fast Checks

const std = @import("std");

const operations = @import("utils").bits.operations;

pub fn bitmapByteCounts() !void {
    try std.testing.expectEqual(@as(u64, 0), operations.bitmapBytes(0));
    try std.testing.expectEqual(@as(u64, 1), operations.bitmapBytes(1));
    try std.testing.expectEqual(@as(u64, 1), operations.bitmapBytes(7));
    try std.testing.expectEqual(@as(u64, 1), operations.bitmapBytes(8));
    try std.testing.expectEqual(@as(u64, 2), operations.bitmapBytes(9));
    try std.testing.expectEqual(@as(u64, 2), operations.bitmapBytes(15));
    try std.testing.expectEqual(@as(u64, 2), operations.bitmapBytes(16));
    try std.testing.expectEqual(@as(u64, 3), operations.bitmapBytes(17));
}

pub fn individualMutations() !void {
    var bitmap = [_]u8{ 0x80, 0x01 };

    operations.setBit(&bitmap, 6);
    operations.setBit(&bitmap, 9);
    operations.setBit(&bitmap, 6);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xc0, 0x03 }, &bitmap);

    operations.clearBit(&bitmap, 7);
    operations.clearBit(&bitmap, 8);
    operations.clearBit(&bitmap, 8);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x40, 0x02 }, &bitmap);
    try std.testing.expect(operations.testBit(&bitmap, 6));
    try std.testing.expect(!operations.testBit(&bitmap, 7));
    try std.testing.expect(!operations.testBit(&bitmap, 8));
    try std.testing.expect(operations.testBit(&bitmap, 9));
}

pub fn outsideStorage() !void {
    var bitmap = [_]u8{ 0x55, 0xaa };

    operations.setBit(&bitmap, 16);
    operations.clearBit(&bitmap, 16);
    operations.setBit(&bitmap, std.math.maxInt(u64));
    operations.clearBit(&bitmap, std.math.maxInt(u64));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x55, 0xaa }, &bitmap);
    try std.testing.expect(operations.testBit(&bitmap, 16));
    try std.testing.expect(operations.testBit(&bitmap, std.math.maxInt(u64)));
    try std.testing.expectEqual(@as(?u64, null), operations.findFirstClear(&bitmap, 16, 20));
    try std.testing.expectEqual(@as(?u64, null), operations.findContiguousClear(&bitmap, 16, 20, 1));

    var empty_bitmap = [_]u8{};
    operations.setBit(&empty_bitmap, 0);
    operations.clearBit(&empty_bitmap, 0);
    try std.testing.expect(operations.testBit(&empty_bitmap, 0));
    try std.testing.expectEqual(@as(?u64, null), operations.findFirstClear(&empty_bitmap, 0, 1));
    try std.testing.expectEqual(@as(?u64, null), operations.findContiguousClear(&empty_bitmap, 0, 1, 1));
}

pub fn rangeMutations() !void {
    var bitmap = [_]u8{ 0x03, 0x80, 0xc0 };

    operations.setRange(&bitmap, 6, 6);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xc3, 0x8f, 0xc0 }, &bitmap);

    operations.clearRange(&bitmap, 7, 4);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x43, 0x88, 0xc0 }, &bitmap);

    operations.setRange(&bitmap, 8, 0);
    operations.clearRange(&bitmap, 8, 0);
    operations.setRange(&bitmap, 22, 4);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x43, 0x88, 0xc0 }, &bitmap);

    operations.clearRange(&bitmap, 22, 4);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x43, 0x88, 0x00 }, &bitmap);
}

pub fn boundedFirstClear() !void {
    var bitmap = [_]u8{ 0xff, 0x1f };

    try std.testing.expectEqual(@as(?u64, null), operations.findFirstClear(&bitmap, 0, 13));
    try std.testing.expectEqual(@as(?u64, 13), operations.findFirstClear(&bitmap, 0, 16));

    operations.clearBit(&bitmap, 12);
    try std.testing.expectEqual(@as(?u64, 12), operations.findFirstClear(&bitmap, 0, 13));

    operations.clearBit(&bitmap, 3);
    try std.testing.expectEqual(@as(?u64, 3), operations.findFirstClear(&bitmap, 0, 13));
    try std.testing.expectEqual(@as(?u64, 12), operations.findFirstClear(&bitmap, 4, 13));
    try std.testing.expectEqual(@as(?u64, null), operations.findFirstClear(&bitmap, 13, 13));
    try std.testing.expectEqual(@as(?u64, null), operations.findFirstClear(&bitmap, 14, 13));
}

pub fn boundedContiguousClear() !void {
    const bitmap = [_]u8{ 0x87, 0x00 };

    try std.testing.expectEqual(@as(?u64, 3), operations.findContiguousClear(&bitmap, 0, 13, 4));
    try std.testing.expectEqual(@as(?u64, 8), operations.findContiguousClear(&bitmap, 4, 13, 4));
    try std.testing.expectEqual(@as(?u64, 8), operations.findContiguousClear(&bitmap, 0, 13, 5));
    try std.testing.expectEqual(@as(?u64, null), operations.findContiguousClear(&bitmap, 0, 13, 6));
    try std.testing.expectEqual(@as(?u64, 9), operations.findContiguousClear(&bitmap, 9, 13, 4));
    try std.testing.expectEqual(@as(?u64, null), operations.findContiguousClear(&bitmap, 9, 13, 5));
    try std.testing.expectEqual(@as(?u64, null), operations.findContiguousClear(&bitmap, 13, 13, 1));
}

pub fn zeroLengthContiguousClear() !void {
    const occupied = [_]u8{ 0xff, 0xff };
    const empty = [_]u8{};

    try std.testing.expectEqual(@as(?u64, 0), operations.findContiguousClear(&occupied, 0, 16, 0));
    try std.testing.expectEqual(@as(?u64, 5), operations.findContiguousClear(&occupied, 5, 16, 0));
    try std.testing.expectEqual(@as(?u64, 16), operations.findContiguousClear(&occupied, 16, 16, 0));
    try std.testing.expectEqual(@as(?u64, null), operations.findContiguousClear(&occupied, 17, 16, 0));
    try std.testing.expectEqual(@as(?u64, 0), operations.findContiguousClear(&empty, 0, 0, 0));
    try std.testing.expectEqual(@as(?u64, 5), operations.findContiguousClear(&empty, 5, 8, 0));
    try std.testing.expectEqual(@as(?u64, 0xffffffffffffffff), operations.findContiguousClear(&empty, 0xffffffffffffffff, 0xffffffffffffffff, 0));
}
