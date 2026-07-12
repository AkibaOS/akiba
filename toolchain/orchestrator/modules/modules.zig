//! Build Module Creation

const std = @import("std");

const names = @import("../strings/names.zig");
const paths = @import("../strings/paths.zig");
const types = @import("../types/types.zig");

pub fn create(builder: *std.Build) types.Modules {
    const common = builder.createModule(.{
        .root_source_file = builder.path(paths.COMMON_ROOT),
    });
    common.addImport(names.MODULE_COMMON, common);

    const shared = builder.createModule(.{
        .root_source_file = builder.path(paths.SHARED_ROOT),
    });
    shared.addImport(names.MODULE_COMMON, common);
    shared.addImport(names.MODULE_SHARED, shared);

    const assembly = builder.createModule(.{
        .root_source_file = builder.path(paths.ASSEMBLY_ROOT),
    });
    assembly.addImport(names.MODULE_ASSEMBLY, assembly);

    return types.Modules{
        .Common = common,
        .Shared = shared,
        .Assembly = assembly,
    };
}
