//! Disk Image Native I O Operations

const std = @import("std");

pub const Operations = struct {
    Context: ?*anyopaque = null,
    ReadFn: *const fn (?*anyopaque, std.fs.File, []u8) anyerror!usize,
    WriteFn: *const fn (?*anyopaque, std.fs.File, []const u8, u64) anyerror!void,
    SyncFn: *const fn (?*anyopaque, std.fs.File) anyerror!void,
    RenameFn: *const fn (?*anyopaque, *std.fs.AtomicFile) anyerror!void,
};
