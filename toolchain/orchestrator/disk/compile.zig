//! Host Disk Tool Build

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps/descriptions.zig");
const types = @import("../types/modules/dependencies.zig");

pub fn artifact(builder: *std.Build, modules: types.Modules) *std.Build.Step.Compile {
    const optimize = builder.standardOptimizeOption(.{});
    const module = builder.createModule(.{
        .root_source_file = builder.path(paths.MKAFSDISK_ROOT),
        .target = builder.graph.host,
        .optimize = optimize,
    });
    module.addImport(names.MODULE_COMMON, modules.Common);
    module.addImport(names.MODULE_SHARED, modules.Shared);
    module.addImport(names.EXECUTABLE_MKAFSDISK, module);

    const entry = builder.createModule(.{
        .root_source_file = builder.path(paths.MKAFSDISK_ENTRY),
        .target = builder.graph.host,
        .optimize = optimize,
    });
    entry.addImport(names.EXECUTABLE_MKAFSDISK, module);
    const executable = builder.addExecutable(.{
        .name = names.EXECUTABLE_MKAFSDISK,
        .root_module = entry,
    });
    return executable;
}

pub fn install(builder: *std.Build, executable: *std.Build.Step.Compile) *std.Build.Step {
    const copy = builder.addInstallArtifact(executable, .{});
    builder.step(names.EXECUTABLE_MKAFSDISK, steps.MKAFSDISK_DESCRIPTION).dependOn(&copy.step);
    return &copy.step;
}
