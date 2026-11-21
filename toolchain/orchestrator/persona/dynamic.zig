//! Link An Installed Persona Binary For The Native ELF Loader

const std = @import("std");

const compile = @import("compile.zig");
const linker = @import("../strings/linker.zig");
const names = @import("../strings/names.zig");
const types = @import("../types/modules/dependencies.zig");

const Definition = @import("../types/persona/definition.zig").Definition;

pub fn artifact(builder: *std.Build, modules: types.Modules, definition: Definition) std.Build.LazyPath {
    const object = builder.addObject(.{
        .name = definition.Name,
        .root_module = compile.module(builder, modules, definition, true),
        .use_llvm = true,
    });
    object.bundle_compiler_rt = true;
    object.link_function_sections = true;
    object.link_data_sections = true;
    const link = builder.addSystemCommand(&.{
        builder.graph.zig_exe,
        linker.LLD,
        linker.PIE,
        linker.NATIVE,
        linker.SYSV_HASH,
        linker.COLLECT_SECTIONS,
        linker.STRIP_SYMBOLS,
        linker.LINK_OPTION,
        linker.EAGER,
        linker.ENTRY,
        definition.Symbol,
        linker.OUTPUT,
    });
    const executable = link.addOutputFileArg(definition.Name);
    link.addFileArg(object.getEmittedBin());
    if (std.mem.eql(u8, definition.Symbol, names.ENTRY_PERSONA)) link.addFileArg(modules.PersonaStartup);
    return executable;
}
