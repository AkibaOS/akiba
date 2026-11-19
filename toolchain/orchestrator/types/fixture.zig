//! Separately Linked Native Diagnostic Outputs

const std = @import("std");

pub const Dynamic = struct {
    Program: std.Build.LazyPath,
    Library: std.Build.LazyPath,
};
