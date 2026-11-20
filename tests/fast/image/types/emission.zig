//! Owned Active AFS Writer Fixture Paths

const std = @import("std");

pub const Paths = struct {
    Allocator: std.mem.Allocator,
    Source: []u8,
    Output: []u8,

    pub fn deinit(self: *Paths) void {
        self.Allocator.free(self.Source);
        self.Allocator.free(self.Output);
        self.* = undefined;
    }
};
