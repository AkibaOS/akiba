//! Build And Install The Standalone Pulse ELF

const std = @import("std");

const installpath = @import("../../../shared/pulse/strings/install.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps/descriptions.zig");
const types = @import("../types/modules/dependencies.zig");

pub fn artifact(builder: *std.Build, modules: types.Modules) *std.Build.Step.Compile {
    const target = builder.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .freestanding, .abi = .none, .ofmt = .elf });
    const assembly = builder.createModule(.{ .root_source_file = builder.path(paths.PERSONA_ASSEMBLY_ROOT) });
    assembly.addImport(names.MODULE_PERSONA_ASSEMBLY, assembly);
    assembly.addImport(names.MODULE_COMMON, modules.Common);
    assembly.addImport(names.MODULE_SHARED, modules.Shared);
    const pulse = builder.createModule(.{ .root_source_file = builder.path(paths.PULSE_ROOT) });
    pulse.addImport(names.MODULE_SHARED, modules.Shared);
    pulse.addImport(names.MODULE_PERSONA_ASSEMBLY, assembly);
    const root = builder.createModule(.{
        .root_source_file = builder.path(paths.PULSE_ENTRY),
        .target = target,
        .optimize = .ReleaseSafe,
        .code_model = .small,
        .pic = false,
        .red_zone = false,
        .strip = true,
    });
    root.addImport(names.MODULE_SHARED, modules.Shared);
    root.addImport(names.MODULE_PERSONA_ASSEMBLY, assembly);
    root.addImport(names.EXECUTABLE_PULSE, pulse);
    const executable = builder.addExecutable(.{
        .name = names.EXECUTABLE_PULSE,
        .root_module = root,
        .linkage = .static,
        .use_llvm = true,
        .use_lld = true,
    });
    executable.entry = .{ .symbol_name = names.ENTRY_PULSE };
    executable.pie = false;
    executable.bundle_compiler_rt = true;
    executable.setLinkerScript(builder.path(paths.PULSE_LINKER));
    return executable;
}

pub fn install(builder: *std.Build, executable: *std.Build.Step.Compile) *std.Build.Step {
    const copy = builder.addInstallFile(executable.getEmittedBin(), installpath.PATH);
    builder.step(names.EXECUTABLE_PULSE, steps.PULSE_DESCRIPTION).dependOn(&copy.step);
    return &copy.step;
}
