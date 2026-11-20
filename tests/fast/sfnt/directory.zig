//! SFNT Directory Regressions

const std = @import("std");

const constants = @import("tests").fast.constants.render;
const fixture = @import("tests").fast.sfnt.fixture;
const sfnt = @import("shared").sfnt;
const types = @import("tests").fast.types.render;

const Directory = sfnt.types.directory.Directory;
const TableFixture = types.TableFixture;

pub fn tableLookupAndBounds() !void {
    var data = fixture.pack(&.{.{ .Tag = constants.HEAD_TAG, .Bytes = &constants.ENDIAN_BYTES }});
    const directory = try Directory.parse(data.Data[0..data.Length]);
    try std.testing.expectEqual(@as(u16, 1), directory.Count);
    try std.testing.expectEqualSlices(u8, &constants.ENDIAN_BYTES, try directory.require(constants.HEAD_TAG));
    try std.testing.expect(directory.find(constants.GLYF_TAG) == null);
    try std.testing.expectError(error.TableMissing, directory.require(constants.GLYF_TAG));
    fixture.writeU32(&data.Data, 20, @intCast(data.Length));
    fixture.writeU32(&data.Data, 24, 0);
    const empty = try Directory.parse(data.Data[0..data.Length]);
    try std.testing.expectEqual(@as(usize, 0), (try empty.require(constants.HEAD_TAG)).len);
    fixture.writeU32(&data.Data, 24, 1);
    try std.testing.expectError(error.TableOutOfBounds, Directory.parse(data.Data[0..data.Length]));
    fixture.writeU32(&data.Data, 20, std.math.maxInt(u32));
    fixture.writeU32(&data.Data, 24, std.math.maxInt(u32));
    try std.testing.expectError(error.TableOutOfBounds, Directory.parse(data.Data[0..data.Length]));
}

pub fn signaturesAndTruncation() !void {
    var data = fixture.pack(&.{.{ .Tag = constants.HEAD_TAG, .Bytes = &constants.ENDIAN_BYTES }});
    try std.testing.expectError(error.UnexpectedEnd, Directory.parse(data.Data[0..3]));
    try std.testing.expectError(error.UnexpectedEnd, Directory.parse(data.Data[0..11]));
    try std.testing.expectError(error.UnexpectedEnd, Directory.parse(data.Data[0..27]));
    fixture.writeU32(&data.Data, 0, sfnt.constants.tags.VERSION_COLLECTION);
    try std.testing.expectError(error.UnsupportedCollection, Directory.parse(data.Data[0..data.Length]));
    fixture.writeU32(&data.Data, 0, sfnt.constants.tags.VERSION_OPENTYPE);
    try std.testing.expectError(error.UnsupportedOutlines, Directory.parse(data.Data[0..data.Length]));
    fixture.writeU32(&data.Data, 0, 0);
    try std.testing.expectError(error.InvalidSignature, Directory.parse(data.Data[0..data.Length]));
    fixture.writeU32(&data.Data, 0, sfnt.constants.tags.VERSION_TRUE);
    _ = try Directory.parse(data.Data[0..data.Length]);
}

pub fn tableGrowth() !void {
    var entries: [constants.SFNT_GROWTH_TABLES]TableFixture = undefined;
    for (&entries, 0..) |*entry, index| {
        entry.* = .{ .Tag = @intCast(index), .Bytes = &.{} };
    }
    entries[entries.len - 1].Bytes = &constants.ENDIAN_BYTES;
    var data = fixture.pack(&entries);
    const directory = try Directory.parse(data.Data[0..data.Length]);
    try std.testing.expectEqual(constants.SFNT_GROWTH_TABLES, directory.Count);
    try std.testing.expectEqualSlices(u8, &constants.ENDIAN_BYTES, try directory.require(entries.len - 1));
    for (0..entries.len - 1) |index| try std.testing.expectEqual(@as(usize, 0), (try directory.require(@intCast(index))).len);
    const payload_end = sfnt.constants.limits.OFFSET_TABLE_SIZE + entries.len * sfnt.constants.limits.TABLE_RECORD_SIZE + constants.ENDIAN_BYTES.len;
    try std.testing.expectError(error.TableOutOfBounds, Directory.parse(data.Data[0 .. payload_end - 1]));
    fixture.writeU16(&data.Data, 4, constants.SFNT_GROWTH_TABLES + 1);
    try std.testing.expectError(error.UnexpectedEnd, Directory.parse(data.Data[0..data.Length]));
}
