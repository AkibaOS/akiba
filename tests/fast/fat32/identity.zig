//! FAT32 Identity Extraction Checks

const std = @import("std");

const constants = @import("tests").fast.constants.storage;
const entries = @import("shared").fat32.constants.entries;
const operations = @import("shared").fat32.write.entry;
const sizes = @import("shared").fat32.constants.sizes;
const stack = @import("shared").fat32.read.stack;
const types = @import("shared").fat32.types.entry;

pub fn shortIdentityExtraction() !void {
    var entry = std.mem.zeroes(types.StackEntry);
    entry.Identity = "README  ".*;
    entry.Extension = "TXT".*;
    entry.ReservedNt = 0x18;
    var output = [_]u8{constants.GUARD_BYTE} ** sizes.SHORT_DISPLAY_LENGTH;
    var length = entry.getShortIdentity(&output);
    try std.testing.expectEqual(@as(usize, 10), length);
    try std.testing.expectEqualSlices(u8, "README.TXT", output[0..length]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ constants.GUARD_BYTE, constants.GUARD_BYTE }, output[length..]);
    entry.Identity = "ABCDEFGH".*;
    entry.Extension = "XYZ".*;
    length = entry.getShortIdentity(&output);
    try std.testing.expectEqual(@as(usize, 12), length);
    try std.testing.expectEqualSlices(u8, "ABCDEFGH.XYZ", &output);
    entry.Extension = "   ".*;
    @memset(&output, constants.GUARD_BYTE);
    length = entry.getShortIdentity(&output);
    try std.testing.expectEqual(@as(usize, 8), length);
    try std.testing.expectEqualSlices(u8, "ABCDEFGH", output[0..length]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** 4), output[length..]);
    entry.Identity = "A B     ".*;
    entry.Extension = "C D".*;
    length = entry.getShortIdentity(&output);
    try std.testing.expectEqualSlices(u8, "A.C", output[0..length]);
    entry.Identity = .{ 0x05, 'I', 'L', 'E', ' ', ' ', ' ', ' ' };
    entry.Extension = "   ".*;
    length = entry.getShortIdentity(&output);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xe5, 'I', 'L', 'E' }, output[0..length]);
    entry.Identity = "        ".*;
    @memset(&output, constants.GUARD_BYTE);
    try std.testing.expectEqual(@as(usize, 0), entry.getShortIdentity(&output));
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** sizes.SHORT_DISPLAY_LENGTH), &output);
}

pub fn shortIdentityMatching() !void {
    var entry = std.mem.zeroes(types.StackEntry);
    entry.Identity = "README  ".*;
    entry.Extension = "TXT".*;
    try std.testing.expect(stack.entryMatchesIdentity(&entry, "readme.txt"));
    try std.testing.expect(stack.entryMatchesIdentity(&entry, "ReAdMe.TxT"));
    try std.testing.expect(!stack.entryMatchesIdentity(&entry, "README"));
    try std.testing.expect(!stack.entryMatchesIdentity(&entry, "README.TX"));
    try std.testing.expect(!stack.entryMatchesIdentity(&entry, "README.TXT\x00"));
}

pub fn lastDotParsing() !void {
    const plain = operations.parseIdentity("README");
    try std.testing.expectEqualSlices(u8, "README", plain.Name);
    try std.testing.expectEqualSlices(u8, "", plain.Extension);
    const multiple = operations.parseIdentity("archive.tar.gz");
    try std.testing.expectEqualSlices(u8, "archive.tar", multiple.Name);
    try std.testing.expectEqualSlices(u8, "gz", multiple.Extension);
    const leading = operations.parseIdentity(".hidden");
    try std.testing.expectEqualSlices(u8, "", leading.Name);
    try std.testing.expectEqualSlices(u8, "hidden", leading.Extension);
    const trailing = operations.parseIdentity("tail.");
    try std.testing.expectEqualSlices(u8, "tail", trailing.Name);
    try std.testing.expectEqualSlices(u8, "", trailing.Extension);
    const empty = operations.parseIdentity("");
    try std.testing.expectEqualSlices(u8, "", empty.Name);
    try std.testing.expectEqualSlices(u8, "", empty.Extension);
    const parent = operations.parseIdentity("..");
    try std.testing.expectEqualSlices(u8, ".", parent.Name);
    try std.testing.expectEqualSlices(u8, "", parent.Extension);
}

pub fn longIdentityCodeUnits() !void {
    var entry = types.LongIdentityEntry{
        .Sequence = 0x43,
        .Identity1 = .{ 0x41, 0x00, 0x2c, 0x67, 0x00, 0x00, 0xff, 0xff, 0x3d, 0xd8 },
        .Attributes = 0x0f,
        .EntryType = 0,
        .Checksum = 0x79,
        .Identity2 = .{ 0x00, 0xde, 0x34, 0x12, 0x42, 0x00, 0xff, 0xff, 0x00, 0x00, 0xa9, 0x03 },
        .FirstCluster = 0,
        .Identity3 = .{ 0x43, 0x00, 0xac, 0x20 },
    };
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(types.LongIdentityEntry));
    try std.testing.expect(entry.isLast());
    try std.testing.expectEqual(@as(u8, 3), entry.getSequence());
    var output: [entries.LFN_CHARS_PER_ENTRY]u16 = undefined;
    entry.extractChars(&output);
    try std.testing.expectEqualSlices(u16, &[_]u16{ 'A', 0x672c, 0, 0xffff, 0xd83d, 0xde00, 0x1234, 'B', 0xffff, 0, 0x03a9, 'C', 0x20ac }, &output);
    entry.Sequence = 0xa5;
    try std.testing.expect(!entry.isLast());
    try std.testing.expectEqual(@as(u8, 5), entry.getSequence());
}
