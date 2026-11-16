//! Per Run Firmware State Preparation

const std = @import("std");

const Paths = @import("checks").types.host.Paths;

pub fn prepare(paths: *const Paths) !void {
    try std.fs.cwd().copyFile(paths.FirmwareTemplate, std.fs.cwd(), paths.Variables, .{});
}
