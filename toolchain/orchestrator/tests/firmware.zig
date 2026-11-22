//! Identity Mapped Firmware Test Application

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
    checks.addImport(names.EXECUTABLE_HIKARI, hikari);
    checks.addImport(names.MODULE_ASSEMBLY, modules.Assembly);
    checks.addImport(names.MODULE_COMMON, modules.Common);
    checks.addImport(names.MODULE_SHARED, modules.Shared);
    const root = builder.createModule(.{
        .root_source_file = builder.path(paths.FIRMWARE_TEST_ROOT),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    root.addImport(names.MODULE_TESTS, checks);
    return builder.addExecutable(.{ .name = names.EXECUTABLE_FIRMWARE_TESTS, .root_module = root });
}
