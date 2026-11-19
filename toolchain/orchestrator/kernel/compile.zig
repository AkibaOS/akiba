//! ELF Kernel Build

const std = @import("std");

const bootloader = @import("../bootloader/bootloader.zig");
const fixture = @import("../tests/fixture.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");
const types = @import("../types/types.zig");

pub fn artifact(builder: *std.Build, modules: types.modules.Modules, guest_checks: bool) *std.Build.Step.Compile {
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
    const options = builder.addOptions();
    options.addOption(bool, names.OPTION_GUEST_CHECKS, guest_checks);
    module.addOptions(names.MODULE_OPTIONS, options);
    if (guest_checks) {
        const hikari = bootloader.compile.module(builder, modules, null, false);
        const checks = builder.createModule(.{ .root_source_file = builder.path(paths.TESTS_ROOT) });
        checks.addImport(names.MODULE_TESTS, checks);
        checks.addImport(names.MODULE_COMMON, modules.Common);
        checks.addImport(names.MODULE_SHARED, modules.Shared);
        checks.addImport(names.MODULE_ASSEMBLY, modules.Assembly);
        checks.addImport(names.MODULE_UTILS, modules.Utils);
        checks.addImport(names.EXECUTABLE_HIKARI, hikari);
        checks.addImport(names.EXECUTABLE_MIRAI, module);
        checks.addAnonymousImport(names.IMPORT_ELF_IMAGE, .{ .root_source_file = fixture.artifact(builder).getEmittedBin() });
        const probes = builder.createModule(.{
            .root_source_file = builder.path(paths.TEST_ASSEMBLY_ROOT),
            .target = target,
            .optimize = .ReleaseSafe,
            .code_model = .kernel,
            .pic = false,
            .red_zone = false,
        });
        probes.addImport(names.MODULE_TESTS, checks);
        checks.addImport(names.MODULE_TEST_ASSEMBLY, probes);
        module.addImport(names.MODULE_TESTS, checks);
    }
    const executable = builder.addExecutable(.{
        .name = if (guest_checks) names.EXECUTABLE_GUEST else names.EXECUTABLE_MIRAI,
        .root_module = module,
        .linkage = .static,
        .use_llvm = true,
        .use_lld = true,
    });
    executable.bundle_compiler_rt = true;
    executable.pie = false;
    executable.entry = .{ .symbol_name = names.ENTRY_MIRAI };
    executable.setLinkerScript(builder.path(paths.LINKER_SCRIPT));
    return executable;
}

pub fn install(builder: *std.Build, executable: *std.Build.Step.Compile) *std.Build.Step {
    const copy = builder.addInstallFile(executable.getEmittedBin(), paths.MIRAI_OUTPUT);
    const step = builder.step(names.EXECUTABLE_MIRAI, steps.MIRAI_DESCRIPTION);
    step.dependOn(&copy.step);
    return &copy.step;
}

pub fn addGuest(builder: *std.Build, modules: types.modules.Modules) *std.Build.Step.Compile {
    const executable = artifact(builder, modules, true);
    const copy = builder.addInstallFile(executable.getEmittedBin(), paths.GUEST_OUTPUT);
    const step = builder.step(names.STEP_GUEST_CHECKS, steps.GUEST_CHECKS_DESCRIPTION);
    step.dependOn(&copy.step);
    return executable;
}
