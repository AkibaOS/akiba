//! Owned Weaver System Library Snapshot

const std = @import("std");

const Metadata = @import("shared").elf.types.dynamic.Metadata;

pub const Library = struct {
    Allocator: std.mem.Allocator,
    Bytes: []const u8,
    Identity: []const u8,
    Metadata: Metadata,

    pub fn deinit(self: *Library) void {
        self.Allocator.free(self.Bytes);
        self.* = undefined;
    }
};
