//! Link And Install The Persona Display Driver

const std = @import("std");

const installpath = @import("../../../shared/display/strings/install.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const persona = @import("../persona/persona.zig");
const types = @import("../types/modules/dependencies.zig");

pub fn artifact(builder: *std.Build, modules: types.Modules) std.Build.LazyPath {
    return persona.dynamic.artifact(builder, modules, .{
        .Name = names.EXECUTABLE_DISPLAY,
        .Root = paths.DISPLAY_ROOT,
        .Entry = paths.DISPLAY_ENTRY,
        .Symbol = names.ENTRY_DISPLAY,
    });
}

pub fn install(builder: *std.Build, executable: std.Build.LazyPath) *std.Build.Step {
    return &builder.addInstallFile(executable, installpath.PATH).step;
}
