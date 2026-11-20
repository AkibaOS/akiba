//! Independent EFI Diagnostic Menu Application

const std = @import("std");

const bootloader = @import("../bootloader/bootloader.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const types = @import("../types/types.zig");

pub fn artifact(builder: *std.Build, modules: types.modules.dependencies.Modules) *std.Build.Step.Compile {
    const target = builder.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .uefi, .abi = .msvc });
    const hikari = bootloader.compile.module(builder, modules, target, false);
    const checks = builder.createModule(.{ .root_source_file = builder.path(paths.TESTS_ROOT) });
    checks.addImport(names.MODULE_TESTS, checks);
    checks.addImport(names.MODULE_ASSEMBLY, modules.Assembly);
    checks.addImport(names.EXECUTABLE_HIKARI, hikari);
    checks.addImport(names.MODULE_SHARED, modules.Shared);
    checks.addImport(names.MODULE_COMMON, modules.Common);
    checks.addImport(names.MODULE_UTILS, modules.Utils);
    const root = builder.createModule(.{ .root_source_file = builder.path(paths.MENU_ROOT), .target = target, .optimize = .ReleaseSafe });
    root.addImport(names.MODULE_TESTS, checks);
    root.addImport(names.EXECUTABLE_HIKARI, hikari);
    root.addImport(names.MODULE_ASSEMBLY, modules.Assembly);
    root.addImport(names.MODULE_SHARED, modules.Shared);
    root.addImport(names.MODULE_COMMON, modules.Common);
    root.addImport(names.MODULE_UTILS, modules.Utils);
    return builder.addExecutable(.{ .name = names.MODULE_MENU, .root_module = root });
}
