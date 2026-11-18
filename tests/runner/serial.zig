//! Per-Boot Serial Evidence

const std = @import("std");

const limits = @import("tests").constants.runner;
const Epoch = @import("tests").types.host.Epoch;

pub fn read(allocator: std.mem.Allocator, epoch: Epoch) ![]u8 {
    if (try epoch.File.getEndPos() < epoch.Start) return error.SerialHistoryLost;
    try epoch.File.seekTo(epoch.Start);
    return epoch.File.readToEndAlloc(allocator, limits.MAX_SERIAL_BYTES);
}
