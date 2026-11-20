//! Boot Handoff Parameter Checks

const std = @import("std");

const constants = @import("tests").fast.constants.storage;
const params = @import("shared").boot.types.params;

pub fn initializedHandoff() !void {
    const actual = params.BootParams.initialize();
    var expected = std.mem.zeroes(params.BootParams);
    expected.Magic = constants.BOOT_MAGIC;
    expected.Version = constants.BOOT_VERSION;
    expected.Size = @sizeOf(params.BootParams);
    try std.testing.expectEqualDeep(expected, actual);
    try std.testing.expect(actual.isValid());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x41, 0x4b, 0x42, 0x4d, 0x49, 0x52, 0x41, 0x49 }, std.mem.asBytes(&actual)[0..@sizeOf(u64)]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 4, 0, 0, 0 }, std.mem.asBytes(&actual)[@sizeOf(u64)..][0..@sizeOf(u32)]);
}

pub fn corruptedMagicAndVersion() !void {
    var handoff = params.BootParams.initialize();
    handoff.Magic ^= 1;
    try std.testing.expect(!handoff.isValid());
    handoff.Magic ^= 1;
    try std.testing.expect(handoff.isValid());
    handoff.Version = 0;
    try std.testing.expect(!handoff.isValid());
    handoff.Version = constants.BOOT_VERSION + 1;
    try std.testing.expect(!handoff.isValid());
    handoff.Version = constants.BOOT_VERSION;
    try std.testing.expect(handoff.isValid());
}

pub fn corruptedSize() !void {
    var handoff = params.BootParams.initialize();
    handoff.Size = 0;
    try std.testing.expect(!handoff.isValid());
    handoff.Size = @sizeOf(params.BootParams) - 1;
    try std.testing.expect(!handoff.isValid());
    handoff.Size = @sizeOf(params.BootParams) + 1;
    try std.testing.expect(!handoff.isValid());
    handoff.Size = @sizeOf(params.BootParams);
    try std.testing.expect(handoff.isValid());
}
