const std = @import("std");

pub fn build(b: *std.Build) void {
    const hikari_module = b.createModule(.{
        .root_source_file = b.path("hikari.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .uefi,
            .abi = .msvc,
        }),
        .optimize = .ReleaseSafe,
    });

    const hikari = b.addExecutable(.{
        .name = "hikari",
        .root_module = hikari_module,
    });

    hikari.entry = .{ .symbol_name = "hikari" };

    b.installArtifact(hikari);

    const copy_step = b.addInstallFile(
        hikari.getEmittedBin(),
        "BOOTX64.EFI",
    );
    copy_step.step.dependOn(&hikari.step);

    b.getInstallStep().dependOn(&copy_step.step);
}
