//! Assemble A Static Bootstrap Persona ELF

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const types = @import("../types/modules/dependencies.zig");

const Definition = @import("../types/persona/definition.zig").Definition;

pub fn module(builder: *std.Build, modules: types.Modules, definition: Definition, pic: bool) *std.Build.Module {
    const target = builder.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .freestanding, .abi = .none, .ofmt = .elf });
    const assembly = builder.createModule(.{ .root_source_file = builder.path(paths.PERSONA_ASSEMBLY_ROOT) });
    assembly.addImport(names.MODULE_PERSONA_ASSEMBLY, assembly);
    assembly.addImport(names.MODULE_COMMON, modules.Common);
    assembly.addImport(names.MODULE_SHARED, modules.Shared);
    const binary = builder.createModule(.{ .root_source_file = builder.path(definition.Root) });
    binary.addImport(definition.Name, binary);
    binary.addImport(names.MODULE_COMMON, modules.Common);
    binary.addImport(names.MODULE_SHARED, modules.Shared);
    binary.addImport(names.MODULE_PERSONA_ASSEMBLY, assembly);
    const root = builder.createModule(.{
        .root_source_file = builder.path(definition.Entry),
        .target = target,
        .optimize = .ReleaseSafe,
        .code_model = .small,
        .pic = pic,
        .red_zone = false,
        .strip = true,
    });
    root.addImport(names.MODULE_SHARED, modules.Shared);
    root.addImport(names.MODULE_PERSONA_ASSEMBLY, assembly);
    root.addImport(definition.Name, binary);
    return root;
}

pub fn artifact(builder: *std.Build, modules: types.Modules, definition: Definition) *std.Build.Step.Compile {
    const executable = builder.addExecutable(.{
        .name = definition.Name,
        .root_module = module(builder, modules, definition, false),
        .linkage = .static,
        .use_llvm = true,
        .use_lld = true,
    });
    executable.root_module.addObjectFile(modules.PersonaStartup);
    executable.entry = .{ .symbol_name = names.ENTRY_PERSONA };
    executable.pie = false;
    executable.bundle_compiler_rt = true;
    if (definition.Linker) |script| executable.setLinkerScript(builder.path(script));
    return executable;
}
