//! Boot Volume Handoff Geometry Checks

const std = @import("std");

const params = @import("shared").boot.types.params;

const Volume = @import("shared").boot.types.volume.Volume;

pub fn copiedRecord() !void {
    var handoff = params.BootParams.initialize();
    try std.testing.expect(!handoff.Volume.isValid());
    handoff.Volume = sample();
    try std.testing.expect(handoff.Volume.isValid());
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(Volume));
    const bytes = std.mem.asBytes(&handoff.Volume);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, bytes[0..4]);
    try std.testing.expectEqualSlices(u8, &.{ 17, 18, 19, 20 }, bytes[16..20]);
    try std.testing.expectEqualSlices(u8, &.{ 8, 7, 6, 5, 4, 3, 2, 1 }, bytes[32..40]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 2, 0, 0, 0, 0, 0, 0 }, bytes[56..64]);
}

pub fn invalidIdentityAndGeometry() !void {
    var volume = sample();
    volume.DiskGUID = @splat(0);
    try std.testing.expect(!volume.isValid());
    volume = sample();
    volume.PartitionGUID = @splat(0);
    try std.testing.expect(!volume.isValid());
    volume = sample();
    volume.FirstLBA = 0;
    try std.testing.expect(!volume.isValid());
    volume = sample();
    volume.LastLBA = volume.FirstLBA;
    try std.testing.expect(volume.isValid());
    volume.LastLBA -= 1;
    try std.testing.expect(!volume.isValid());
    volume = sample();
    volume.LastLBA = volume.DiskLastLBA;
    try std.testing.expect(!volume.isValid());
    volume = sample();
    volume.LastLBA = std.math.maxInt(u64);
    try std.testing.expect(!volume.isValid());
    volume = sample();
    volume.BlockBytes = 0;
    try std.testing.expect(!volume.isValid());
    volume.BlockBytes = 768;
    try std.testing.expect(!volume.isValid());
    volume.BlockBytes = 4096;
    try std.testing.expect(volume.isValid());
    volume.Reserved = 1;
    try std.testing.expect(!volume.isValid());
}

fn sample() Volume {
    return .{
        .DiskGUID = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
        .PartitionGUID = .{ 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32 },
        .FirstLBA = 0x0102030405060708,
        .LastLBA = 0x0102030405061708,
        .DiskLastLBA = 0x0102030405062708,
        .BlockBytes = 512,
    };
}
