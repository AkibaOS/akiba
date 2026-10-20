//! ELF Kernel Build

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");
const types = @import("../types/types.zig");

pub fn add(builder: *std.Build, modules: types.modules.Modules) *std.Build.Step {
    const target = builder.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
    });
    const module = builder.createModule(.{
        .root_source_file = builder.path(paths.MIRAI_ROOT),
        .target = target,
        .optimize = .ReleaseSafe,
        .code_model = .kernel,
        .pic = false,
        .red_zone = false,
    });
    module.addImport(names.MODULE_COMMON, modules.Common);
    module.addImport(names.MODULE_SHARED, modules.Shared);
    module.addImport(names.MODULE_ASSEMBLY, modules.Assembly);
    module.addImport(names.MODULE_UTILS, modules.Utils);
    module.addImport(names.EXECUTABLE_MIRAI, module);

    const executable = builder.addExecutable(.{
        .name = names.EXECUTABLE_MIRAI,
        .root_module = module,
        .linkage = .static,
        .use_llvm = true,
        .use_lld = true,
    });
    executable.bundle_compiler_rt = true;
    executable.pie = false;
    executable.entry = .{ .symbol_name = names.ENTRY_MIRAI };
    executable.setLinkerScript(builder.path(paths.LINKER_SCRIPT));

    const copy = builder.addInstallFile(executable.getEmittedBin(), paths.MIRAI_OUTPUT);
    const step = builder.step(names.EXECUTABLE_MIRAI, steps.MIRAI_DESCRIPTION);
    step.dependOn(&copy.step);
    return &copy.step;
}
