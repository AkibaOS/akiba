//! Cached Identity Mapped Firmware Test Image

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const storage = @import("storage.zig");
const types = @import("../types/types.zig");

pub fn image(builder: *std.Build, modules: types.modules.Modules, packer: *std.Build.Step.Compile) std.Build.LazyPath {
    const target = builder.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .uefi, .abi = .msvc });
    const hikari = builder.createModule(.{ .root_source_file = builder.path(paths.HIKARI_ROOT), .target = target, .optimize = .ReleaseSafe });
    hikari.addImport(names.EXECUTABLE_HIKARI, hikari);
    hikari.addImport(names.MODULE_ASSEMBLY, modules.Assembly);
    hikari.addImport(names.MODULE_COMMON, modules.Common);
    hikari.addImport(names.MODULE_SHARED, modules.Shared);
    hikari.addImport(names.MODULE_UTILS, modules.Utils);
    const checks = builder.createModule(.{ .root_source_file = builder.path(paths.TESTS_ROOT) });
    checks.addImport(names.MODULE_TESTS, checks);
    checks.addImport(names.EXECUTABLE_HIKARI, hikari);
    checks.addImport(names.MODULE_ASSEMBLY, modules.Assembly);
    checks.addImport(names.MODULE_COMMON, modules.Common);
    checks.addImport(names.MODULE_SHARED, modules.Shared);
    checks.addImport(names.MODULE_UTILS, modules.Utils);
    const root = builder.createModule(.{
        .root_source_file = builder.path(paths.FIRMWARE_TEST_ROOT),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    root.addImport(names.MODULE_TESTS, checks);
    const executable = builder.addExecutable(.{ .name = names.EXECUTABLE_FIRMWARE_TESTS, .root_module = root });
    const stage = builder.addWriteFiles();
    _ = stage.addCopyDirectory(builder.path(paths.RESOURCES_ROOT), paths.DIRECTORY_ROOT, .{});
    _ = stage.addCopyFile(executable.getEmittedBin(), paths.HIKARI_OUTPUT);
    storage.add(builder, stage);
    const pack = builder.addRunArtifact(packer);
    pack.addDirectoryArg(stage.getDirectory());
    const result = pack.addOutputFileArg(paths.FIRMWARE_IMAGE_NAME);
    pack.addArg(paths.GUEST_IMAGE_MB);
    return result;
}
