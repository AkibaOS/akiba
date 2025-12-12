const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const exe = b.addExecutable(.{
        .name = "echo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("echo.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
        }),
    });

    exe.setLinkerScript(b.path("../../toolchain/linker/akiba.binary.linker"));

    b.installArtifact(exe);
}
