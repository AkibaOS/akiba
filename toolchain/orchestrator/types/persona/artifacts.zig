//! Built Persona Artifacts And Explicit Installed Outputs

const std = @import("std");

const declarations = @import("../../constants/persona/catalog.zig");

pub const ID = std.meta.FieldEnum(@TypeOf(declarations.BINARIES));

pub const Output = struct {
    Path: []const u8,
    File: std.Build.LazyPath,
};

pub const Collection = struct {
    Files: [std.enums.values(ID).len]std.Build.LazyPath = undefined,

    pub fn file(self: *const Collection, identifier: ID) std.Build.LazyPath {
        return self.Files[@intFromEnum(identifier)];
    }
};
