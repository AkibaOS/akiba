//! Build The Pulse ELF With Its Exact Bootstrap Weaver Payload

const std = @import("std");

const asset = @import("../../../shared/pulse/strings/bootstrap.zig");
const installpath = @import("../../../shared/pulse/strings/install.zig");
const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const persona = @import("../persona/persona.zig");
const steps = @import("../strings/steps/descriptions.zig");
const types = @import("../types/modules/dependencies.zig");

pub fn artifact(builder: *std.Build, modules: types.Modules, weaver: *std.Build.Step.Compile) *std.Build.Step.Compile {
    const executable = persona.compile.artifact(builder, modules, .{
        .Name = names.EXECUTABLE_PULSE,
        .Root = paths.PULSE_ROOT,
        .Entry = paths.PULSE_ENTRY,
        .Symbol = names.ENTRY_PULSE,
        .Linker = paths.PULSE_LINKER,
    });
    executable.root_module.addAnonymousImport(asset.WEAVER_IMPORT, .{ .root_source_file = weaver.getEmittedBin() });
    return executable;
}

pub fn install(builder: *std.Build, executable: *std.Build.Step.Compile) *std.Build.Step {
    const copy = builder.addInstallFile(executable.getEmittedBin(), installpath.PATH);
    builder.step(names.EXECUTABLE_PULSE, steps.PULSE_DESCRIPTION).dependOn(&copy.step);
    return &copy.step;
}
