//! Explicit Manual Check Targets

const std = @import("std");

const boot = @import("boot.zig");
const diagnostics = @import("../bootloader/bootloader.zig");
const diskfixture = @import("../../../tests/fixtures/strings/elf/boot.zig");
const firmware = @import("firmware.zig");
const fixture = @import("fixture.zig");
const kernel = @import("../kernel/kernel.zig");
const menu = @import("menu.zig");
const names = @import("../strings/names.zig");
const progress = @import("pack.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps/descriptions.zig");
const storage = @import("storage.zig");
const suites = @import("../strings/suites.zig");
const types = @import("../types/types.zig");

pub fn add(builder: *std.Build, modules: types.modules.dependencies.Modules, bootloader: *std.Build.Step.Compile, ordinary: *std.Build.Step.Compile, packer: *std.Build.Step.Compile) void {
    const checks = builder.createModule(.{ .root_source_file = builder.path(paths.TESTS_ROOT) });
    checks.addImport(names.MODULE_TESTS, checks);
    checks.addImport(names.MODULE_COMMON, modules.Common);
    checks.addImport(names.MODULE_SHARED, modules.Shared);
    checks.addImport(names.MODULE_UTILS, modules.Utils);
    const weaver = builder.createModule(.{ .root_source_file = builder.path(paths.WEAVER_ROOT) });
    weaver.addImport(names.MODULE_WEAVER, weaver);
    weaver.addImport(names.MODULE_COMMON, modules.Common);
    weaver.addImport(names.MODULE_SHARED, modules.Shared);
    weaver.addImport(names.MODULE_UTILS, modules.Utils);
    checks.addImport(names.MODULE_WEAVER, weaver);
    const tool = builder.createModule(.{ .root_source_file = builder.path(paths.MKAFSDISK_ROOT) });
    tool.addImport(names.EXECUTABLE_MKAFSDISK, tool);
    tool.addImport(names.MODULE_SHARED, modules.Shared);
    tool.addImport(names.MODULE_UTILS, modules.Utils);
    checks.addImport(names.EXECUTABLE_MKAFSDISK, tool);
    const dynamic = fixture.dynamic(builder);
    const step = builder.step(names.STEP_FAST_CHECKS, steps.FAST_CHECKS_DESCRIPTION);
    for (suites.FAST) |suite| {
        const root = builder.createModule(.{
            .root_source_file = builder.path(suite.Root),
            .target = builder.graph.host,
            .optimize = .Debug,
        });
        root.addImport(names.MODULE_TESTS, checks);
        root.addImport(names.MODULE_COMMON, modules.Common);
        root.addImport(names.MODULE_SHARED, modules.Shared);
        root.addImport(names.MODULE_UTILS, modules.Utils);
        root.addImport(names.MODULE_WEAVER, weaver);
        if (std.mem.eql(u8, suite.Root, paths.WEAVER_TEST_ROOT)) {
            root.addAnonymousImport(names.IMPORT_DYNAMIC_IMAGE, .{ .root_source_file = dynamic.Program });
            root.addAnonymousImport(names.IMPORT_DYNAMIC_LIBRARY, .{ .root_source_file = dynamic.Library });
        }
        const executable_name = builder.fmt(suites.EXECUTABLE, .{suite.Name});
        const tests = builder.addTest(.{ .name = executable_name, .root_module = root, .use_llvm = true });
        const run = builder.addRunArtifact(tests);
        run.has_side_effects = true;
        step.dependOn(&run.step);
    }
    const guest = kernel.compile.addGuest(builder, modules, dynamic);
    const selector = boot.artifact(builder, modules, .{
        .Diagnostic = diagnostics.compile.artifact(builder, modules, true),
        .Firmware = firmware.artifact(builder, modules),
        .Menu = menu.artifact(builder, modules),
        .Ordinary = bootloader,
    });
    const stage = builder.addWriteFiles();
    _ = stage.addCopyDirectory(builder.path(paths.RESOURCES_ROOT), paths.DIRECTORY_ROOT, .{});
    _ = stage.addCopyFile(selector.getEmittedBin(), paths.HIKARI_OUTPUT);
    _ = stage.addCopyFile(ordinary.getEmittedBin(), paths.MIRAI_OUTPUT);
    _ = stage.addCopyFile(guest.getEmittedBin(), paths.GUEST_OUTPUT);
    _ = stage.addCopyFile(dynamic.Program, diskfixture.PATH);
    storage.add(builder, stage);
    const image = progress.image(builder, stage, packer, paths.GUEST_IMAGE_NAME);
    const runner_options = builder.addOptions();
    runner_options.addOptionPath(names.OPTION_GUEST_IMAGE, image);
    const runner_checks = builder.createModule(.{ .root_source_file = builder.path(paths.TESTS_ROOT) });
    runner_checks.addImport(names.MODULE_TESTS, runner_checks);
    runner_checks.addOptions(names.MODULE_RUNNER_OPTIONS, runner_options);
    const host_os = builder.graph.host.result.os.tag;
    const host = builder.createModule(.{
        .root_source_file = builder.path(paths.RUNNER_ROOT),
        .target = builder.graph.host,
        .optimize = .ReleaseSafe,
        .link_libc = host_os != .windows and host_os != .linux,
    });
    host.addImport(names.MODULE_TESTS, runner_checks);
    const runner = builder.addExecutable(.{ .name = names.EXECUTABLE_RUNNER, .root_module = host });
    const install = builder.addInstallArtifact(runner, .{});
    const runner_step = builder.step(names.STEP_GUEST_RUNNER, steps.GUEST_RUNNER_DESCRIPTION);
    runner_step.dependOn(&install.step);
}
