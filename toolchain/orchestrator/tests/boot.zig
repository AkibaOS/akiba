//! Build The EFI Selector For One Diagnostic Medium

const std = @import("std");

const bootloader = @import("../bootloader/bootloader.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const types = @import("../types/types.zig");
const Applications = @import("../types/boot.zig").Applications;

pub fn artifact(builder: *std.Build, modules: types.modules.dependencies.Modules, images: Applications) *std.Build.Step.Compile {
    const target = builder.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .uefi, .abi = .msvc });
    const hikari = bootloader.compile.module(builder, modules, target, false);
    const checks = builder.createModule(.{ .root_source_file = builder.path(paths.TESTS_ROOT) });
    checks.addImport(names.MODULE_TESTS, checks);
    checks.addImport(names.EXECUTABLE_HIKARI, hikari);
    checks.addImport(names.MODULE_ASSEMBLY, modules.Assembly);
    checks.addImport(names.MODULE_COMMON, modules.Common);
    const root = builder.createModule(.{ .root_source_file = builder.path(paths.SELECTOR_ROOT), .target = target, .optimize = .ReleaseSafe });
    root.addImport(names.MODULE_TESTS, checks);
    root.addImport(names.EXECUTABLE_HIKARI, hikari);
    root.addImport(names.MODULE_COMMON, modules.Common);
    root.addAnonymousImport(names.IMPORT_DIAGNOSTIC_BOOT, .{ .root_source_file = images.Diagnostic.getEmittedBin() });
    root.addAnonymousImport(names.IMPORT_FIRMWARE_BOOT, .{ .root_source_file = images.Firmware.getEmittedBin() });
    root.addAnonymousImport(names.IMPORT_MENU_BOOT, .{ .root_source_file = images.Menu.getEmittedBin() });
    root.addAnonymousImport(names.IMPORT_ORDINARY_BOOT, .{ .root_source_file = images.Ordinary.getEmittedBin() });
    return builder.addExecutable(.{ .name = names.EXECUTABLE_SELECTOR, .root_module = root });
}
