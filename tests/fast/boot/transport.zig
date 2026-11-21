//! Selected Boot Transport Handoff Regressions

const std = @import("std");

const path = @import("shared").boot.device.path;
const samples = @import("tests").fast.constants.boot.path;

const BootParams = @import("shared").boot.types.params.BootParams;
const Transport = @import("shared").boot.types.transport.Transport;

pub fn completePaths() !void {
    try std.testing.expectEqual(Transport.Sata, path.decode(&(samples.PCI ++ samples.SATA ++ samples.END)));
    try std.testing.expectEqual(Transport.Sata, path.decode(&(samples.PCI ++ samples.SATA ++ samples.END ++ samples.REMAINDER)));
    try std.testing.expectEqual(Transport.Other, path.decode(&(samples.PCI ++ samples.VENDOR ++ samples.END)));
    try std.testing.expectEqual(Transport.Other, path.decode(&(samples.PCI ++ samples.SATA ++ samples.VENDOR ++ samples.END)));
    try std.testing.expectEqual(Transport.Other, path.decode(&(samples.SATA ++ samples.END)));
}

pub fn malformedPaths() !void {
    try std.testing.expectEqual(Transport.Unknown, path.decode(&samples.INVALID_LENGTH));
    try std.testing.expectEqual(Transport.Unknown, path.decode(&(samples.PCI ++ samples.SHORT_SATA ++ samples.END)));
    try std.testing.expectEqual(Transport.Unknown, path.decode(&(samples.PCI ++ samples.SATA ++ samples.INSTANCE ++ samples.END)));
    try std.testing.expectEqual(Transport.Unknown, path.decode(&(samples.PCI ++ samples.SATA)));
    try std.testing.expectEqual(Transport.Unknown, path.decode(samples.PCI[0 .. samples.PCI.len - 1]));
}

pub fn wireTag() !void {
    var handoff = BootParams.initialize();
    try std.testing.expectEqual(@intFromEnum(Transport.Unknown), handoff.Transport);
    handoff.Transport = @intFromEnum(Transport.Sata);
    try std.testing.expectEqualSlices(u8, &samples.SATA_TAG, std.mem.asBytes(&handoff.Transport));
    try std.testing.expect(handoff.isValid() and !handoff.Volume.isValid());
    handoff.Transport = std.math.maxInt(u32);
    try std.testing.expect(!handoff.isValid());
}
