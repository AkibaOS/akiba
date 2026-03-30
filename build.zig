const std = @import("std");

pub const version = "1.0.0";
pub const kernel_location = "/system/akiba/mirai.kernel";
pub const font_location = "/system/akiba/fonts/akiba.psf";

pub fn build(b: *std.Build) void {
    const hikari_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
        .abi = .msvc,
    });

    const hikari_module = b.createModule(.{
        .root_source_file = b.path("hikari/hikari.zig"),
        .target = hikari_target,
        .optimize = .ReleaseSafe,
    });

    const hikari = b.addExecutable(.{
        .name = "hikari",
        .root_module = hikari_module,
    });

    const hikari_copy = b.addInstallFile(
        hikari.getEmittedBin(),
        "EFI/BOOT/BOOTX64.EFI",
    );
    hikari_copy.step.dependOn(&hikari.step);

    const hikari_step = b.step("hikari", "Build Hikari bootloader");
    hikari_step.dependOn(&hikari_copy.step);

    const mirai_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const mirai_module = b.createModule(.{
        .root_source_file = b.path("mirai/mirai.zig"),
        .target = mirai_target,
        .optimize = .ReleaseSafe,
        .code_model = .kernel,
    });

    const mirai = b.addExecutable(.{
        .name = "mirai",
        .root_module = mirai_module,
    });

    mirai.entry = .{ .symbol_name = "mirai_entry" };
    mirai.setLinkerScript(b.path("linker/mirai.linker"));

    const mirai_copy = b.addInstallFile(
        mirai.getEmittedBin(),
        "system/akiba/mirai.kernel",
    );
    mirai_copy.step.dependOn(&mirai.step);

    const mirai_step = b.step("mirai", "Build Mirai kernel");
    mirai_step.dependOn(&mirai_copy.step);

    const native_target = b.standardTargetOptions(.{});
    const native_optimize = b.standardOptimizeOption(.{});

    const mkafsdisk_module = b.createModule(.{
        .root_source_file = b.path("toolchain/mkafsdisk/main.zig"),
        .target = native_target,
        .optimize = native_optimize,
    });

    const mkafsdisk = b.addExecutable(.{
        .name = "mkafsdisk",
        .root_module = mkafsdisk_module,
    });

    const mkafsdisk_install = b.addInstallArtifact(mkafsdisk, .{});

    const mkafsdisk_step = b.step("mkafsdisk", "Build mkafsdisk tool");
    mkafsdisk_step.dependOn(&mkafsdisk_install.step);

    const all_step = b.step("all", "Build everything");
    all_step.dependOn(&hikari_copy.step);
    all_step.dependOn(&mirai_copy.step);
    all_step.dependOn(&mkafsdisk_install.step);

    b.default_step = all_step;

    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
}
