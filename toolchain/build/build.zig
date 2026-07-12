//! Build Functions

const std = @import("std");
const strings = @import("../../common/strings/build.zig");

pub fn build(b: *std.Build) void {
    const common_module = b.createModule(.{
        .root_source_file = b.path(strings.COMMON_ROOT),
    });

    const shared_module = b.createModule(.{
        .root_source_file = b.path(strings.SHARED_ROOT),
    });
    shared_module.addImport(strings.MODULE_COMMON, common_module);

    const asm_module = b.createModule(.{
        .root_source_file = b.path(strings.ASM_ROOT),
    });

    const hikari_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
        .abi = .msvc,
    });

    const hikari_module = b.createModule(.{
        .root_source_file = b.path(strings.HIKARI_ROOT),
        .target = hikari_target,
        .optimize = .ReleaseSafe,
    });
    hikari_module.addImport(strings.MODULE_COMMON, common_module);
    hikari_module.addImport(strings.MODULE_SHARED, shared_module);

    const hikari = b.addExecutable(.{
        .name = strings.HIKARI_NAME,
        .root_module = hikari_module,
    });

    const hikari_copy = b.addInstallFile(
        hikari.getEmittedBin(),
        strings.HIKARI_OUTPUT,
    );
    hikari_copy.step.dependOn(&hikari.step);

    const hikari_step = b.step(strings.HIKARI_NAME, strings.STEP_HIKARI_DESC);
    hikari_step.dependOn(&hikari_copy.step);

    const mirai_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const mirai_module = b.createModule(.{
        .root_source_file = b.path(strings.MIRAI_ROOT),
        .target = mirai_target,
        .optimize = .ReleaseSafe,
        .code_model = .kernel,
    });
    mirai_module.addImport(strings.MODULE_COMMON, common_module);
    mirai_module.addImport(strings.MODULE_SHARED, shared_module);
    mirai_module.addImport(strings.MODULE_ASM, asm_module);

    const mirai = b.addExecutable(.{
        .name = strings.MIRAI_NAME,
        .root_module = mirai_module,
    });

    mirai.entry = .{ .symbol_name = strings.MIRAI_ENTRY };
    mirai.setLinkerScript(b.path(strings.LINKER_SCRIPT));

    const mirai_copy = b.addInstallFile(
        mirai.getEmittedBin(),
        strings.MIRAI_OUTPUT,
    );
    mirai_copy.step.dependOn(&mirai.step);

    const mirai_step = b.step(strings.MIRAI_NAME, strings.STEP_MIRAI_DESC);
    mirai_step.dependOn(&mirai_copy.step);

    const native_target = b.standardTargetOptions(.{});
    const native_optimize = b.standardOptimizeOption(.{});

    const mkafsdisk_module = b.createModule(.{
        .root_source_file = b.path(strings.MKAFSDISK_ROOT),
        .target = native_target,
        .optimize = native_optimize,
    });
    mkafsdisk_module.addImport(strings.MODULE_COMMON, common_module);
    mkafsdisk_module.addImport(strings.MODULE_SHARED, shared_module);

    const mkafsdisk = b.addExecutable(.{
        .name = strings.MKAFSDISK_NAME,
        .root_module = mkafsdisk_module,
    });

    const mkafsdisk_install = b.addInstallArtifact(mkafsdisk, .{});

    const mkafsdisk_step = b.step(strings.MKAFSDISK_NAME, strings.STEP_MKAFSDISK_DESC);
    mkafsdisk_step.dependOn(&mkafsdisk_install.step);

    const all_step = b.step(strings.STEP_ALL, strings.STEP_ALL_DESC);
    all_step.dependOn(&hikari_copy.step);
    all_step.dependOn(&mirai_copy.step);
    all_step.dependOn(&mkafsdisk_install.step);

    b.default_step = all_step;

    const clean_step = b.step(strings.STEP_CLEAN, strings.STEP_CLEAN_DESC);
    clean_step.dependOn(&b.addRemoveDirTree(b.path(strings.OUT_DIR)).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path(strings.CACHE_DIR)).step);
}
