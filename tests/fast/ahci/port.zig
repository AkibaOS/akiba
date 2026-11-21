//! AHCI Native Disk Candidate Classification

const std = @import("std");

const decode = @import("shared").ahci.discover.port;
const samples = @import("tests").fast.constants.ahci.link;

const Kind = @import("shared").ahci.types.discover.port.Kind;

pub fn knownKinds() !void {
    try std.testing.expectEqual(Kind.AtaDisk, decode.classify(samples.ACTIVE, samples.ATA_DISK));
    try std.testing.expectEqual(Kind.PacketDevice, decode.classify(samples.ACTIVE, samples.OPTICAL));
    try std.testing.expectEqual(Kind.Empty, decode.classify(samples.EMPTY, samples.ATA_DISK));
}

pub fn unverifiable() !void {
    try std.testing.expectEqual(Kind.Unverifiable, decode.classify(samples.ACTIVE, samples.UNRECOGNIZED));
    try std.testing.expectEqual(Kind.Unverifiable, decode.classify(samples.ASLEEP, samples.ATA_DISK));
    try std.testing.expectEqual(Kind.Unverifiable, decode.classify(samples.UNESTABLISHED, samples.OPTICAL));
}
