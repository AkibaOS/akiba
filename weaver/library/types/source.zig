//! Origin Based Source Of Owned Library Bytes

const std = @import("std");

const ReadError = @import("weaver").library.errors.library.ReadError;

pub const Source = struct {
    Context: *const anyopaque,
    ReadFromOrigin: *const fn (*const anyopaque, std.mem.Allocator, []const []const u8, []const u8) ReadError!?[]u8,
};
