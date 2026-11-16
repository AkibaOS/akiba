//! Explicit Manual Check Targets

const std = @import("std");

const kernel = @import("../kernel/kernel.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");
const types = @import("../types/types.zig");

pub fn add(builder: *std.Build, modules: types.modules.Modules, bootloader: *std.Build.Step.Compile, packer: *std.Build.Step.Compile) void {
    const checks = builder.createModule(.{ .root_source_file = builder.path(paths.TESTS_ROOT) });
    checks.addImport(names.MODULE_TESTS, checks);
    checks.addImport(names.MODULE_COMMON, modules.Common);
    checks.addImport(names.MODULE_SHARED, modules.Shared);
    checks.addImport(names.MODULE_UTILS, modules.Utils);
    const root = builder.createModule(.{
        .root_source_file = builder.path(paths.FAST_TESTS_ROOT),
        .target = builder.graph.host,
        .optimize = .Debug,
    });
    root.addImport(names.MODULE_TESTS, checks);
    const tests = builder.addTest(.{ .name = names.EXECUTABLE_TESTS, .root_module = root });
    const run = builder.addRunArtifact(tests);
    const step = builder.step(names.STEP_FAST_CHECKS, steps.FAST_CHECKS_DESCRIPTION);
    step.dependOn(&run.step);
    const guest = kernel.compile.addGuest(builder, modules);
    const stage = builder.addWriteFiles();
    _ = stage.addCopyDirectory(builder.path(paths.RESOURCES_ROOT), paths.DIRECTORY_ROOT, .{});
    _ = stage.addCopyFile(bootloader.getEmittedBin(), paths.HIKARI_OUTPUT);
    _ = stage.addCopyFile(guest.getEmittedBin(), paths.MIRAI_OUTPUT);
    const pack = builder.addRunArtifact(packer);
    pack.addDirectoryArg(stage.getDirectory());
    const image = pack.addOutputFileArg(paths.GUEST_IMAGE_NAME);
    pack.addArg(paths.GUEST_IMAGE_MB);
    const runner_options = builder.addOptions();
    runner_options.addOptionPath(names.OPTION_GUEST_IMAGE, image);
    const runner_checks = builder.createModule(.{ .root_source_file = builder.path(paths.TESTS_ROOT) });
    runner_checks.addImport(names.MODULE_TESTS, runner_checks);
    runner_checks.addOptions(names.MODULE_RUNNER_OPTIONS, runner_options);
    const host = builder.createModule(.{
        .root_source_file = builder.path(paths.RUNNER_ROOT),
        .target = builder.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = builder.graph.host.result.os.tag != .windows,
    });
    host.addImport(names.MODULE_TESTS, runner_checks);
    const runner = builder.addExecutable(.{ .name = names.EXECUTABLE_RUNNER, .root_module = host });
    const install = builder.addInstallArtifact(runner, .{});
    const runner_step = builder.step(names.STEP_GUEST_RUNNER, steps.GUEST_RUNNER_DESCRIPTION);
    runner_step.dependOn(&install.step);
}
