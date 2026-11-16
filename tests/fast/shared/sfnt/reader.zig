//! Checked Endian Reader Regressions

const std = @import("std");

const constants = @import("tests").constants.render;
const sfnt = @import("shared").sfnt;

const Reader = sfnt.types.reader.Reader;

pub fn endianAndCursor() !void {
    var reader = Reader.initialize(&constants.ENDIAN_BYTES);
    try std.testing.expectEqual(@as(u8, 0x81), try reader.readU8());
    try std.testing.expectEqual(@as(u16, 0x1234), try reader.readU16());
    try std.testing.expectEqual(@as(i16, -2), try reader.readI16());
    try std.testing.expectEqual(@as(u32, 0x89ABCDEF), try reader.readU32());
    try std.testing.expectEqual(@as(usize, 0), reader.remaining());
    try std.testing.expectError(error.UnexpectedEnd, reader.readU8());
    try std.testing.expectEqual(constants.ENDIAN_BYTES.len, reader.Offset);
}

pub fn failedReadsPreservePosition() !void {
    var reader = Reader.initialize(&constants.ENDIAN_BYTES);
    try reader.seek(constants.ENDIAN_BYTES.len - 1);
    try std.testing.expectError(error.UnexpectedEnd, reader.readU16());
    try std.testing.expectError(error.UnexpectedEnd, reader.readI16());
    try std.testing.expectError(error.UnexpectedEnd, reader.readU32());
    try std.testing.expectError(error.UnexpectedEnd, reader.seek(constants.ENDIAN_BYTES.len + 1));
    try std.testing.expectError(error.UnexpectedEnd, reader.skip(2));
    try std.testing.expectEqual(constants.ENDIAN_BYTES.len - 1, reader.Offset);
    try std.testing.expectEqual(@as(u8, 0xEF), try reader.readU8());
    try reader.seek(constants.ENDIAN_BYTES.len);
    try reader.skip(0);
    try std.testing.expectError(error.UnexpectedEnd, reader.skip(1));
}

pub fn sliceBounds() !void {
    var reader = Reader.initialize(&constants.ENDIAN_BYTES);
    try reader.seek(3);
    try std.testing.expectEqualSlices(u8, &constants.ENDIAN_BYTES, try reader.slice(0, constants.ENDIAN_BYTES.len));
    try std.testing.expectEqual(@as(usize, 0), (try reader.slice(constants.ENDIAN_BYTES.len, 0)).len);
    try std.testing.expectError(error.TableOutOfBounds, reader.slice(constants.ENDIAN_BYTES.len, 1));
    try std.testing.expectError(error.TableOutOfBounds, reader.slice(constants.ENDIAN_BYTES.len + 1, 0));
    try std.testing.expectError(error.TableOutOfBounds, reader.slice(1, std.math.maxInt(usize)));
    try std.testing.expectError(error.TableOutOfBounds, reader.slice(std.math.maxInt(usize), 1));
    try std.testing.expectEqual(@as(usize, 3), reader.Offset);
}
