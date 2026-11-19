//! Allocator Owned Native ELF Relocation Plans

const std = @import("std");

pub const Write = struct {
    Address: u64,
    Value: u64,
};

pub const Plan = struct {
    Allocator: std.mem.Allocator,
    Writes: []const Write,

    pub fn deinit(self: *Plan) void {
        self.Allocator.free(self.Writes);
        self.Writes = &.{};
    }
};
