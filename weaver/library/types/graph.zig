//! An Owned Closure Of Weaver Library Dependencies

const std = @import("std");

const Library = @import("weaver").library.types.library.Library;

pub const Index = std.StringHashMapUnmanaged(usize);

pub const Graph = struct {
    Allocator: std.mem.Allocator,
    Libraries: []Library,
    Names: Index,

    pub fn get(self: *const Graph, name: []const u8) ?*const Library {
        const index = self.Names.get(name) orelse return null;
        return &self.Libraries[index];
    }

    pub fn deinit(self: *Graph) void {
        self.Names.deinit(self.Allocator);
        for (self.Libraries) |*library| library.deinit();
        self.Allocator.free(self.Libraries);
        self.Names = .empty;
        self.Libraries = &.{};
    }
};
