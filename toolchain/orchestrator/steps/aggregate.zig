//! Aggregate Build Steps

const std = @import("std");

const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");

pub fn add(builder: *std.Build, bootloader: *std.Build.Step, kernel: *std.Build.Step, disk: *std.Build.Step) void {
    const all = builder.step(steps.ALL, steps.ALL_DESCRIPTION);
    all.dependOn(bootloader);
    all.dependOn(kernel);
    all.dependOn(disk);
    builder.default_step = all;

    const clean = builder.step(steps.CLEAN, steps.CLEAN_DESCRIPTION);
    clean.dependOn(&builder.addRemoveDirTree(builder.path(paths.OUTPUT_DIRECTORY)).step);
    clean.dependOn(&builder.addRemoveDirTree(builder.path(paths.CACHE_DIRECTORY)).step);
}
