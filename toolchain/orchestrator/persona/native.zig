//! Compile And Export The Common Persona Startup Object

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");

pub fn artifact(builder: *std.Build, common: *std.Build.Module) std.Build.LazyPath {
    const target = builder.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .freestanding, .abi = .none, .ofmt = .elf });
    const assembly = builder.createModule(.{ .root_source_file = builder.path(paths.PERSONA_ASSEMBLY_ROOT) });
    assembly.addImport(names.MODULE_PERSONA_ASSEMBLY, assembly);
    assembly.addImport(names.MODULE_COMMON, common);
    const root = builder.createModule(.{
        .root_source_file = builder.path(paths.PERSONA_STARTUP),
        .target = target,
        .optimize = .ReleaseSafe,
        .code_model = .small,
        .pic = true,
        .red_zone = false,
        .strip = true,
    });
    root.addImport(names.MODULE_PERSONA_ASSEMBLY, assembly);
    const object = builder.addObject(.{ .name = names.OBJECT_PERSONA, .root_module = root, .use_llvm = true });
    return object.getEmittedBin();
}

pub fn exportSdk(builder: *std.Build, startup: std.Build.LazyPath) void {
    const sdk = builder.step(names.STEP_SDK, names.SDK_DESCRIPTION);
    sdk.dependOn(&builder.addInstallDirectory(.{
        .source_dir = builder.path(paths.SDK_DIRECTORY),
        .install_dir = .prefix,
        .install_subdir = paths.SDK_DIRECTORY,
    }).step);
    sdk.dependOn(&builder.addInstallFile(startup, paths.SDK_STARTUP).step);
}
