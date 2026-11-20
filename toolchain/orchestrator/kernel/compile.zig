//! ELF Kernel Build

const std = @import("std");

const bootloader = @import("../bootloader/bootloader.zig");
const fixture = @import("../tests/fixture.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");
const types = @import("../types/types.zig");

const Dynamic = @import("../types/fixture.zig").Dynamic;

pub fn artifact(builder: *std.Build, modules: types.modules.Modules, images: ?Dynamic) *std.Build.Step.Compile {
    const guest_checks = images != null;
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
    if (images) |dynamic| {
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
        checks.addAnonymousImport(names.IMPORT_PROVISION_IMAGE, .{ .root_source_file = fixture.provision(builder).getEmittedBin() });
        checks.addAnonymousImport(names.IMPORT_DYNAMIC_IMAGE, .{ .root_source_file = dynamic.Program });
        checks.addAnonymousImport(names.IMPORT_DYNAMIC_LIBRARY, .{ .root_source_file = dynamic.Library });
        const weaver = builder.createModule(.{ .root_source_file = builder.path(paths.WEAVER_ROOT) });
        weaver.addImport(names.MODULE_WEAVER, weaver);
        weaver.addImport(names.MODULE_COMMON, modules.Common);
        weaver.addImport(names.MODULE_SHARED, modules.Shared);
        weaver.addImport(names.MODULE_UTILS, modules.Utils);
        checks.addImport(names.MODULE_WEAVER, weaver);
        checks.addAnonymousImport(names.IMPORT_WEAVER_FIXTURE, .{ .root_source_file = fixture.weaverRequest(builder, modules, weaver, dynamic).getEmittedBin() });
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
    const root = builder.createModule(.{
        .root_source_file = builder.path(paths.MIRAI_ENTRY),
        .target = target,
        .optimize = .ReleaseSafe,
        .code_model = .kernel,
        .pic = false,
        .red_zone = false,
    });
    root.addImport(names.EXECUTABLE_MIRAI, module);
    root.addImport(names.MODULE_UTILS, modules.Utils);
    const executable = builder.addExecutable(.{
        .name = if (guest_checks) names.EXECUTABLE_GUEST else names.EXECUTABLE_MIRAI,
        .root_module = root,
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

pub fn addGuest(builder: *std.Build, modules: types.modules.Modules, images: Dynamic) *std.Build.Step.Compile {
    const executable = artifact(builder, modules, images);
    const copy = builder.addInstallFile(executable.getEmittedBin(), paths.GUEST_OUTPUT);
    const step = builder.step(names.STEP_GUEST_CHECKS, steps.GUEST_CHECKS_DESCRIPTION);
    step.dependOn(&copy.step);
    return executable;
}
