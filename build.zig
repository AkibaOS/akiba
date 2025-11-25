const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const mirai_module = b.createModule(.{
        .root_source_file = b.path("mirai/mirai.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });

    const kernel = b.addExecutable(.{
        .name = "mirai.akibakernel",
        .root_module = mirai_module,
    });

    kernel.addAssemblyFile(b.path("boot/boot.s"));
    kernel.setLinkerScript(b.path("linker/mirai.linker"));

    b.installArtifact(kernel);
}
