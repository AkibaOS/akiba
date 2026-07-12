//! Build Modules Type

const std = @import("std");

pub const Modules = struct {
    Common: *std.Build.Module,
    Shared: *std.Build.Module,
    Assembly: *std.Build.Module,
};
