//! SFNT Directory Regressions

const std = @import("std");

const constants = @import("tests").constants.render;
const fixture = @import("tests").fast.shared.sfnt.fixture;
const sfnt = @import("shared").sfnt;
const types = @import("tests").types.render;

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

pub fn tableCountLimit() !void {
    var entries: [sfnt.constants.limits.MAX_TABLES]TableFixture = undefined;
    for (&entries, 0..) |*entry, index| {
        entry.* = .{ .Tag = @intCast(index), .Bytes = &.{} };
    }
    var data = fixture.pack(&entries);
    const directory = try Directory.parse(data.Data[0..data.Length]);
    try std.testing.expectEqual(sfnt.constants.limits.MAX_TABLES, directory.Count);
    fixture.writeU16(&data.Data, 4, sfnt.constants.limits.MAX_TABLES + 1);
    try std.testing.expectError(error.TooManyTables, Directory.parse(data.Data[0..data.Length]));
}
