//! Build And Install Each Declared Persona Artifact Once

const std = @import("std");

const asset = @import("../../../shared/pulse/strings/bootstrap.zig");
const compile = @import("compile.zig");
const declarations = @import("../constants/persona/catalog.zig");
const dynamic = @import("dynamic.zig");
const messages = @import("../strings/persona/messages.zig");
const names = @import("../strings/names.zig");

const Collection = @import("../types/persona/artifacts.zig").Collection;
const Definition = @import("../types/persona/definition.zig").Definition;
const ID = @import("../types/persona/artifacts.zig").ID;
const Modules = @import("../types/modules/dependencies.zig").Modules;
const Output = @import("../types/persona/artifacts.zig").Output;

comptime {
    const fields = std.meta.fields(@TypeOf(declarations.BINARIES));
    const pulse = @intFromEnum(ID.Pulse);
    if (pulse <= @intFromEnum(ID.Weaver) or pulse <= @intFromEnum(ID.Ahci) or pulse <= @intFromEnum(ID.Afs)) @compileError(messages.INVALID_ORDER);
    for (fields, 0..) |field, index| {
        const definition = @field(declarations.BINARIES, field.name);
        for (fields[0..index]) |earlier| {
            const previous = @field(declarations.BINARIES, earlier.name);
            if (std.mem.eql(u8, definition.Name, previous.Name)) @compileError(messages.INVALID_ORDER);
            if (definition.Install) |path| if (previous.Install) |other| {
                if (std.mem.eql(u8, path, other)) @compileError(messages.DUPLICATE_INSTALL);
            };
        }
    }
}

pub fn build(builder: *std.Build, modules: Modules) Collection {
    var result: Collection = .{};
    inline for (std.meta.fields(@TypeOf(declarations.BINARIES))) |field| {
        const definition = @field(declarations.BINARIES, field.name);
        result.Files[@intFromEnum(@field(ID, field.name))] = switch (definition.Profile) {
            .Fixed => compile.artifact(builder, modules, definition).getEmittedBin(),
            .Dynamic => dynamic.artifact(builder, modules, definition),
            .Pulse => embedded(builder, modules, definition, &result),
        };
    }
    return result;
}

pub fn install(builder: *std.Build, artifacts: *const Collection) *std.Build.Step {
    const group = builder.step(names.STEP_PERSONA, messages.DESCRIPTION);
    inline for (std.meta.fields(@TypeOf(declarations.BINARIES))) |field| {
        const definition = @field(declarations.BINARIES, field.name);
        if (definition.Install) |path| {
            const copy = builder.addInstallFile(artifacts.file(@field(ID, field.name)), path);
            group.dependOn(&copy.step);
            builder.step(definition.Name, builder.fmt(messages.INSTALL, .{definition.Name})).dependOn(&copy.step);
        }
    }
    return group;
}

pub fn outputs(builder: *std.Build, artifacts: *const Collection, prefix: []const Output) []const Output {
    var count = prefix.len;
    inline for (std.meta.fields(@TypeOf(declarations.BINARIES))) |field| {
        if (@field(declarations.BINARIES, field.name).Install != null) count += 1;
    }
    const result = builder.allocator.alloc(Output, count) catch @panic(messages.OUT_OF_MEMORY);
    @memcpy(result[0..prefix.len], prefix);
    var index = prefix.len;
    inline for (std.meta.fields(@TypeOf(declarations.BINARIES))) |field| {
        if (@field(declarations.BINARIES, field.name).Install) |path| {
            result[index] = .{ .Path = path, .File = artifacts.file(@field(ID, field.name)) };
            index += 1;
        }
    }
    return result;
}

fn embedded(builder: *std.Build, modules: Modules, definition: Definition, artifacts: *const Collection) std.Build.LazyPath {
    const executable = compile.artifact(builder, modules, definition);
    executable.root_module.addAnonymousImport(asset.WEAVER_IMPORT, .{ .root_source_file = artifacts.file(.Weaver) });
    executable.root_module.addAnonymousImport(asset.AHCI_IMPORT, .{ .root_source_file = artifacts.file(.Ahci) });
    executable.root_module.addAnonymousImport(asset.AFS_IMPORT, .{ .root_source_file = artifacts.file(.Afs) });
    return executable.getEmittedBin();
}
