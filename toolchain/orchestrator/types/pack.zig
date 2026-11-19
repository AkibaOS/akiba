//! Cached Diagnostic Image Packing Step State

const std = @import("std");

pub const Pack = struct {
    Step: std.Build.Step,
    Source: std.Build.LazyPath,
    Tool: std.Build.LazyPath,
    ImageName: []const u8,
    Output: std.Build.GeneratedFile,
};
