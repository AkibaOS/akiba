//! FAT32 Table Byte Checks

const std = @import("std");

const constants = @import("tests").constants.storage;
const operations = @import("shared").fat32.write.boot;

pub fn initializedTableBytes() !void {
    var guarded = [_]u8{constants.GUARD_BYTE} ** 40;
    const table = guarded[constants.GUARD_BYTES .. guarded.len - constants.GUARD_BYTES];
    operations.initFatTable(table);
    try std.testing.expectEqualSlices(u8, &([_]u8{ 0xf8, 0xff, 0xff, 0x0f, 0xff, 0xff, 0xff, 0x0f, 0xff, 0xff, 0xff, 0x0f } ++ [_]u8{0} ** 20), table);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[0..constants.GUARD_BYTES]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[guarded.len - constants.GUARD_BYTES ..]);
    var minimum = [_]u8{constants.SCRATCH_BYTE} ** 12;
    operations.initFatTable(&minimum);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xf8, 0xff, 0xff, 0x0f, 0xff, 0xff, 0xff, 0x0f, 0xff, 0xff, 0xff, 0x0f }, &minimum);
}

pub fn allocationAndLinks() !void {
    var guarded = [_]u8{constants.GUARD_BYTE} ** 40;
    const table = guarded[constants.GUARD_BYTES .. guarded.len - constants.GUARD_BYTES];
    @memset(table, 0);
    operations.allocateCluster(table, 3);
    operations.allocateCluster(table, 7);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xff, 0xff, 0xff, 0x0f }, table[12..16]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xff, 0xff, 0xff, 0x0f }, table[28..32]);
    operations.linkClusters(table, 3, 4);
    operations.linkClusters(table, 4, 0xf1234567);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 12 ++ [_]u8{ 4, 0, 0, 0, 0x67, 0x45, 0x23, 0xf1 } ++ [_]u8{0} ** 8 ++ [_]u8{ 0xff, 0xff, 0xff, 0x0f }), table);
    const original = guarded;
    operations.allocateCluster(table, 8);
    operations.linkClusters(table, 8, 2);
    try std.testing.expectEqualSlices(u8, &original, &guarded);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[0..constants.GUARD_BYTES]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[guarded.len - constants.GUARD_BYTES ..]);
}
