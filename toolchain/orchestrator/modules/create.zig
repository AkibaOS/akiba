//! Build Module Creation

const std = @import("std");

const names = @import("../strings/names.zig");
const native = @import("../persona/native.zig");
const paths = @import("../strings/paths.zig");
const types = @import("../types/modules/dependencies.zig");

pub fn create(builder: *std.Build) types.Modules {
    const common = builder.createModule(.{
        .root_source_file = builder.path(paths.COMMON_ROOT),
    });
    common.addImport(names.MODULE_COMMON, common);

    const compiler = builder.createModule(.{
        .root_source_file = builder.path(paths.COMPILER_ROOT),
    });
    compiler.addImport(names.MODULE_COMPILER, compiler);

    const sdk = builder.createModule(.{ .root_source_file = builder.path(paths.SDK_ROOT) });
    sdk.addImport(names.MODULE_SDK, sdk);

    const shared = builder.createModule(.{
        .root_source_file = builder.path(paths.SHARED_ROOT),
    });
    shared.addImport(names.MODULE_COMMON, common);
    shared.addImport(names.MODULE_SHARED, shared);
    shared.addImport(names.MODULE_SDK, sdk);
    shared.addAnonymousImport(names.IMPORT_FONT, .{ .root_source_file = builder.path(paths.FONT_RESOURCE) });

    const assembly = builder.createModule(.{
        .root_source_file = builder.path(paths.ASSEMBLY_ROOT),
    });
    assembly.addImport(names.MODULE_ASSEMBLY, assembly);
    assembly.addImport(names.MODULE_COMMON, common);

    return .{
        .Common = common,
        .Shared = shared,
        .Assembly = assembly,
        .Compiler = compiler,
        .PersonaStartup = native.artifact(builder, common),
    };
}
