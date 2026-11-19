//! Independent UEFI Bootloader Build

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");
const types = @import("../types/modules.zig");

pub fn module(builder: *std.Build, modules: types.Modules, target: ?std.Build.ResolvedTarget, diagnostics: bool) *std.Build.Module {
    const root = builder.createModule(.{
        .root_source_file = builder.path(paths.HIKARI_ROOT),
        .target = target,
        .optimize = if (target != null) .ReleaseSafe else null,
    });
    root.addImport(names.MODULE_ASSEMBLY, modules.Assembly);
    root.addImport(names.MODULE_COMMON, modules.Common);
    root.addImport(names.MODULE_SHARED, modules.Shared);
    root.addImport(names.MODULE_UTILS, modules.Utils);
    root.addImport(names.EXECUTABLE_HIKARI, root);
    const options = builder.addOptions();
    options.addOption(bool, names.OPTION_DIAGNOSTIC_LOADER, diagnostics);
    root.addOptions(names.MODULE_OPTIONS, options);
    return root;
}

pub fn artifact(builder: *std.Build, modules: types.Modules, diagnostics: bool) *std.Build.Step.Compile {
    const target = builder.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
        .abi = .msvc,
    });
    const root = module(builder, modules, target, diagnostics);
    return builder.addExecutable(.{
        .name = names.EXECUTABLE_HIKARI,
        .root_module = root,
    });
}

pub fn install(builder: *std.Build, executable: *std.Build.Step.Compile) *std.Build.Step {
    const copy = builder.addInstallFile(executable.getEmittedBin(), paths.HIKARI_OUTPUT);
    const step = builder.step(names.EXECUTABLE_HIKARI, steps.HIKARI_DESCRIPTION);
    step.dependOn(&copy.step);
    return &copy.step;
}
