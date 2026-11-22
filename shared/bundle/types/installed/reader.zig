//! Exact Unit Reads And Typed Stack Enumeration

const std = @import("std");

const Entry = @import("shared").afs.types.read.list.Entry;
const ReadError = @import("shared").bundle.errors.installed.reader.ReadError;

pub const Reader = struct {
    Context: *anyopaque,
    Read: *const fn (*anyopaque, std.mem.Allocator, []const u8, usize) ReadError!?[]u8,
    Size: *const fn (*anyopaque, []const u8) ReadError!?u64,
    List: *const fn (*anyopaque, []const u8, u64) ReadError!?Entry,
};
