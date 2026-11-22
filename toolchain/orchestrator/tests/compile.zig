//! Explicit Manual Check Targets

const std = @import("std");

const afspath = @import("../../../shared/afs/strings/install.zig");
const ahcipath = @import("../../../shared/ahci/strings/install.zig");
const boot = @import("boot.zig");
const diagnostics = @import("../bootloader/bootloader.zig");
const diskfixture = @import("../../../tests/fixtures/strings/elf/boot.zig");
const displaypath = @import("../../../shared/display/strings/install.zig");
const firmware = @import("firmware.zig");
const fixture = @import("fixture.zig");
const installed = @import("../../../tests/fixtures/strings/weaver.zig");
const kernel = @import("../kernel/kernel.zig");
const keyboardpath = @import("../../../shared/keyboard/strings/install.zig");
const menu = @import("menu.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const progress = @import("pack.zig");
const pulsepath = @import("../../../shared/pulse/strings/install.zig");
const services = @import("../../../tests/fixtures/strings/service.zig");
const steps = @import("../strings/steps/descriptions.zig");
const storage = @import("storage.zig");
const suites = @import("../strings/suites.zig");
const types = @import("../types/types.zig");

pub fn add(builder: *std.Build, modules: types.modules.dependencies.Modules, bootloader: *std.Build.Step.Compile, ordinary: *std.Build.Step.Compile, packer: *std.Build.Step.Compile, pulse: *std.Build.Step.Compile, ahci: *std.Build.Step.Compile, afs: *std.Build.Step.Compile, keyboard_artifact: std.Build.LazyPath, display_artifact: std.Build.LazyPath) void {
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
    const supervisor = builder.createModule(.{ .root_source_file = builder.path(paths.PULSE_ROOT) });
    supervisor.addImport(names.EXECUTABLE_PULSE, supervisor);
    supervisor.addImport(names.MODULE_SHARED, modules.Shared);
    supervisor.addImport(names.MODULE_COMMON, modules.Common);
    checks.addImport(names.EXECUTABLE_PULSE, supervisor);
    const tool = builder.createModule(.{ .root_source_file = builder.path(paths.MKAFSDISK_ROOT) });
    tool.addImport(names.EXECUTABLE_MKAFSDISK, tool);
    tool.addImport(names.MODULE_SHARED, modules.Shared);
    tool.addImport(names.MODULE_UTILS, modules.Utils);
    checks.addImport(names.EXECUTABLE_MKAFSDISK, tool);
    const keyboard = builder.createModule(.{ .root_source_file = builder.path(paths.KEYBOARD_ROOT) });
    keyboard.addImport(names.EXECUTABLE_KEYBOARD, keyboard);
    keyboard.addImport(names.MODULE_SHARED, modules.Shared);
    const display = builder.createModule(.{ .root_source_file = builder.path(paths.DISPLAY_ROOT) });
    display.addImport(names.EXECUTABLE_DISPLAY, display);
    display.addImport(names.MODULE_SHARED, modules.Shared);
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
        root.addImport(names.EXECUTABLE_PULSE, supervisor);
        if (std.mem.eql(u8, suite.Name, names.EXECUTABLE_DISPLAY)) {
            root.addImport(names.EXECUTABLE_DISPLAY, display);
            root.addAnonymousImport(names.IMPORT_DISPLAY_IMAGE, .{ .root_source_file = display_artifact });
        }
        if (std.mem.eql(u8, suite.Name, names.EXECUTABLE_KEYBOARD)) {
            root.addImport(names.EXECUTABLE_KEYBOARD, keyboard);
            root.addAnonymousImport(names.IMPORT_KEYBOARD_IMAGE, .{ .root_source_file = keyboard_artifact });
        }
        if (std.mem.eql(u8, suite.Root, paths.WEAVER_TEST_ROOT)) {
            root.addAnonymousImport(names.IMPORT_AHCI_IMAGE, .{ .root_source_file = ahci.getEmittedBin() });
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
    _ = stage.addCopyDirectory(builder.path(paths.RESOURCES_ROOT), paths.DIRECTORY_ROOT, .{ .exclude_extensions = &.{services.WORLD_UNIT} });
    _ = stage.add(services.WORLD_PATH, services.WORLD);
    _ = stage.addCopyFile(selector.getEmittedBin(), paths.HIKARI_OUTPUT);
    _ = stage.addCopyFile(ordinary.getEmittedBin(), paths.MIRAI_OUTPUT);
    _ = stage.addCopyFile(pulse.getEmittedBin(), pulsepath.PATH);
    _ = stage.addCopyFile(ahci.getEmittedBin(), ahcipath.PATH);
    _ = stage.addCopyFile(afs.getEmittedBin(), afspath.PATH);
    _ = stage.addCopyFile(keyboard_artifact, keyboardpath.PATH);
    _ = stage.addCopyFile(display_artifact, displaypath.PATH);
    _ = stage.addCopyFile(guest.getEmittedBin(), paths.GUEST_OUTPUT);
    _ = stage.addCopyFile(dynamic.Program, diskfixture.PATH);
    _ = stage.addCopyFile(dynamic.Program, installed.INSTALLED_ELF);
    _ = stage.addCopyFile(dynamic.Library, installed.INSTALLED_LIBRARY);
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
