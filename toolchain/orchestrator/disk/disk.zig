//! Disk Tool Build

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");
const types = @import("../types/types.zig");

pub fn add(builder: *std.Build, modules: types.Modules) *std.Build.Step {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const module = builder.createModule(.{
        .root_source_file = builder.path(paths.MKAFSDISK_ROOT),
        .target = target,
        .optimize = optimize,
    });
    module.addImport(names.MODULE_COMMON, modules.Common);
    module.addImport(names.MODULE_SHARED, modules.Shared);
    module.addImport(names.EXECUTABLE_MKAFSDISK, module);

    const executable = builder.addExecutable(.{
        .name = names.EXECUTABLE_MKAFSDISK,
        .root_module = module,
    });

    const install = builder.addInstallArtifact(executable, .{});

    const step = builder.step(names.EXECUTABLE_MKAFSDISK, steps.MKAFSDISK_DESCRIPTION);
    step.dependOn(&install.step);

    return &install.step;
}
