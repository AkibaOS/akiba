//! Bootloader Build

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");
const types = @import("../types/types.zig");

pub fn add(builder: *std.Build, modules: types.Modules) *std.Build.Step {
    const target = builder.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
        .abi = .msvc,
    });

    const module = builder.createModule(.{
        .root_source_file = builder.path(paths.HIKARI_ROOT),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    module.addImport(names.MODULE_COMMON, modules.Common);
    module.addImport(names.MODULE_SHARED, modules.Shared);
    module.addImport(names.EXECUTABLE_HIKARI, module);

    const executable = builder.addExecutable(.{
        .name = names.EXECUTABLE_HIKARI,
        .root_module = module,
    });

    const copy = builder.addInstallFile(executable.getEmittedBin(), paths.HIKARI_OUTPUT);
    copy.step.dependOn(&executable.step);

    const step = builder.step(names.EXECUTABLE_HIKARI, steps.HIKARI_DESCRIPTION);
    step.dependOn(&copy.step);

    return &copy.step;
}
