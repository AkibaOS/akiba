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

    const utils = builder.createModule(.{
        .root_source_file = builder.path(paths.UTILS_ROOT),
    });
    utils.addImport(names.MODULE_COMMON, common);
    utils.addImport(names.MODULE_UTILS, utils);

    const shared = builder.createModule(.{
        .root_source_file = builder.path(paths.SHARED_ROOT),
    });
    shared.addImport(names.MODULE_COMMON, common);
    shared.addImport(names.MODULE_SHARED, shared);
    shared.addImport(names.MODULE_UTILS, utils);

    const assembly = builder.createModule(.{
        .root_source_file = builder.path(paths.ASSEMBLY_ROOT),
    });
    assembly.addImport(names.MODULE_ASSEMBLY, assembly);

    return types.Modules{
        .Common = common,
        .Shared = shared,
        .Assembly = assembly,
        .Utils = utils,
    };
}
