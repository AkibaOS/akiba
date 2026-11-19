//! Compiler Produced ELF Test Artifact

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");

pub fn artifact(builder: *std.Build) *std.Build.Step.Compile {
    return build(builder, paths.ELF_FIXTURE_ROOT, paths.ELF_FIXTURE_LINKER, names.EXECUTABLE_ELF_FIXTURE);
}

pub fn provision(builder: *std.Build) *std.Build.Step.Compile {
    return build(builder, paths.PROVISION_FIXTURE_ROOT, paths.PROVISION_FIXTURE_LINKER, names.EXECUTABLE_PROVISION_FIXTURE);
}

fn build(builder: *std.Build, source_path: []const u8, linker_path: []const u8, name: []const u8) *std.Build.Step.Compile {
    const target = builder.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
    });
    const assembly = builder.createModule(.{ .root_source_file = builder.path(paths.ELF_FIXTURE_ASSEMBLY) });
    assembly.addImport(names.MODULE_FIXTURE_ASSEMBLY, assembly);
    const owner = builder.createModule(.{ .root_source_file = builder.path(paths.ELF_FIXTURE_OWNER) });
    owner.addImport(names.MODULE_FIXTURE, owner);
    owner.addImport(names.MODULE_FIXTURE_ASSEMBLY, assembly);
    const root = builder.createModule(.{
        .root_source_file = builder.path(source_path),
        .target = target,
        .optimize = .ReleaseSafe,
        .code_model = .small,
        .pic = false,
        .red_zone = false,
    });
    root.addImport(names.MODULE_FIXTURE, owner);
    root.addImport(names.MODULE_FIXTURE_ASSEMBLY, assembly);
    const executable = builder.addExecutable(.{
        .name = name,
        .root_module = root,
        .linkage = .static,
        .use_llvm = true,
        .use_lld = true,
    });
    executable.entry = .{ .symbol_name = names.ENTRY_ELF_FIXTURE };
    executable.pie = false;
    executable.bundle_compiler_rt = true;
    executable.setLinkerScript(builder.path(linker_path));
    return executable;
}
