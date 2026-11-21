//! Build The First Real Resident Weaver ELF

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const persona = @import("../persona/persona.zig");
const types = @import("../types/modules/dependencies.zig");

pub fn artifact(builder: *std.Build, modules: types.Modules) *std.Build.Step.Compile {
    return persona.compile.artifact(builder, modules, .{
        .Name = names.MODULE_WEAVER,
        .Root = paths.WEAVER_ROOT,
        .Entry = paths.WEAVER_ENTRY,
        .Symbol = names.ENTRY_WEAVER,
        .Linker = paths.WEAVER_LINKER,
    });
}
