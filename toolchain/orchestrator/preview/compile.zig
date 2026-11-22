//! Host Font Preview Build

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps/descriptions.zig");
const types = @import("../types/modules/dependencies.zig");

pub fn add(builder: *std.Build, modules: types.Modules) *std.Build.Step {
    const module = builder.createModule(.{
        .root_source_file = builder.path(paths.FONTPREVIEW_ROOT),
        .target = builder.graph.host,
        .optimize = .Debug,
    });
    module.addImport(names.MODULE_COMMON, modules.Common);
    module.addImport(names.MODULE_SHARED, modules.Shared);
    module.addImport(names.EXECUTABLE_FONTPREVIEW, module);

    const entry = builder.createModule(.{
        .root_source_file = builder.path(paths.FONTPREVIEW_ENTRY),
        .target = builder.graph.host,
        .optimize = .Debug,
    });
    entry.addImport(names.EXECUTABLE_FONTPREVIEW, module);
    const executable = builder.addExecutable(.{
        .name = names.EXECUTABLE_FONTPREVIEW,
        .root_module = entry,
    });
    const install = builder.addInstallArtifact(executable, .{});
    builder.step(names.EXECUTABLE_FONTPREVIEW, steps.FONTPREVIEW_DESCRIPTION).dependOn(&install.step);
    return &install.step;
}
