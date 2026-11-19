//! Compiler Produced ELF Test Artifact

const std = @import("std");

const linker = @import("../strings/linker.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");

const Dynamic = @import("../types/fixture.zig").Dynamic;
const Modules = @import("../types/modules.zig").Modules;

pub fn artifact(builder: *std.Build) *std.Build.Step.Compile {
    return build(builder, paths.ELF_FIXTURE_ROOT, paths.ELF_FIXTURE_LINKER, names.EXECUTABLE_ELF_FIXTURE);
}

pub fn provision(builder: *std.Build) *std.Build.Step.Compile {
    return build(builder, paths.PROVISION_FIXTURE_ROOT, paths.PROVISION_FIXTURE_LINKER, names.EXECUTABLE_PROVISION_FIXTURE);
}

pub fn dynamic(builder: *std.Build) Dynamic {
    const assembly = builder.createModule(.{ .root_source_file = builder.path(paths.ELF_FIXTURE_ASSEMBLY) });
    assembly.addImport(names.MODULE_FIXTURE_ASSEMBLY, assembly);
    const program = object(builder, paths.DYNAMIC_FIXTURE_ROOT, names.OBJECT_DYNAMIC_FIXTURE);
    program.root_module.addImport(names.MODULE_FIXTURE_ASSEMBLY, assembly);
    program.root_module.addImport(names.MODULE_TESTS, checks(builder));
    const library = object(builder, paths.DYNAMIC_FIXTURE_LIBRARY, names.OBJECT_DYNAMIC_LIBRARY);
    const shared = builder.addSystemCommand(&.{ builder.graph.zig_exe, linker.LLD, linker.SHARED, linker.SYSV_HASH, linker.SONAME, names.OUTPUT_DYNAMIC_LIBRARY, linker.LINK_OPTION, linker.EAGER, linker.OUTPUT });
    const library_file = shared.addOutputFileArg(names.OUTPUT_DYNAMIC_LIBRARY);
    shared.addFileArg(library.getEmittedBin());
    const executable = builder.addSystemCommand(&.{ builder.graph.zig_exe, linker.LLD, linker.PIE, linker.NATIVE, linker.SYSV_HASH, linker.LINK_OPTION, linker.EAGER, linker.ENTRY, names.ENTRY_ELF_FIXTURE, linker.OUTPUT });
    const program_file = executable.addOutputFileArg(names.OUTPUT_DYNAMIC_FIXTURE);
    executable.addFileArg(program.getEmittedBin());
    executable.addFileArg(library_file);
    return .{ .Program = program_file, .Library = library_file };
}

pub fn weaverRequest(builder: *std.Build, modules: Modules, weaver: *std.Build.Module, artifacts: Dynamic) *std.Build.Step.Compile {
    const executable = build(builder, paths.WEAVER_FIXTURE_ROOT, paths.ELF_FIXTURE_LINKER, names.EXECUTABLE_WEAVER_FIXTURE);
    const root = executable.root_module;
    root.addImport(names.MODULE_TESTS, checks(builder));
    root.addImport(names.MODULE_SHARED, modules.Shared);
    root.addImport(names.MODULE_WEAVER, weaver);
    root.addAnonymousImport(names.IMPORT_DYNAMIC_IMAGE, .{ .root_source_file = artifacts.Program });
    root.addAnonymousImport(names.IMPORT_DYNAMIC_LIBRARY, .{ .root_source_file = artifacts.Library });
    return executable;
}

fn checks(builder: *std.Build) *std.Build.Module {
    const module = builder.createModule(.{ .root_source_file = builder.path(paths.TESTS_ROOT) });
    module.addImport(names.MODULE_TESTS, module);
    return module;
}

fn object(builder: *std.Build, source: []const u8, name: []const u8) *std.Build.Step.Compile {
    const target = builder.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
    });
    const module = builder.createModule(.{
        .root_source_file = builder.path(source),
        .target = target,
        .optimize = .ReleaseFast,
        .pic = true,
        .red_zone = false,
    });
    return builder.addObject(.{ .name = name, .root_module = module, .use_llvm = true });
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
