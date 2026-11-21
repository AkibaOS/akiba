//! Build And Install The Standalone AHCI Device Driver

const std = @import("std");

const installpath = @import("../../../shared/ahci/strings/install.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const persona = @import("../persona/persona.zig");
const types = @import("../types/modules/dependencies.zig");

pub fn artifact(builder: *std.Build, modules: types.Modules) *std.Build.Step.Compile {
    return persona.compile.artifact(builder, modules, .{
        .Name = names.EXECUTABLE_AHCI,
        .Root = paths.AHCI_ROOT,
        .Entry = paths.AHCI_ENTRY,
        .Symbol = names.ENTRY_AHCI,
        .Linker = paths.AHCI_LINKER,
    });
}

pub fn install(builder: *std.Build, executable: *std.Build.Step.Compile) *std.Build.Step {
    return &builder.addInstallFile(executable.getEmittedBin(), installpath.PATH).step;
}
