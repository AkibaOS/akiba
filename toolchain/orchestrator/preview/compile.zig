//! Host Font Preview Build

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");
const types = @import("../types/modules.zig");

pub fn add(builder: *std.Build, modules: types.Modules) *std.Build.Step {
    const module = builder.createModule(.{
        .root_source_file = builder.path(paths.FONTPREVIEW_ROOT),
        .target = builder.graph.host,
        .optimize = .Debug,
    });
    module.addImport(names.MODULE_COMMON, modules.Common);
    module.addImport(names.MODULE_SHARED, modules.Shared);
    module.addImport(names.MODULE_UTILS, modules.Utils);
    module.addImport(names.EXECUTABLE_FONTPREVIEW, module);

    const executable = builder.addExecutable(.{
        .name = names.EXECUTABLE_FONTPREVIEW,
        .root_module = module,
    });
    const install = builder.addInstallArtifact(executable, .{});
    builder.step(names.EXECUTABLE_FONTPREVIEW, steps.FONTPREVIEW_DESCRIPTION).dependOn(&install.step);
    return &install.step;
}
