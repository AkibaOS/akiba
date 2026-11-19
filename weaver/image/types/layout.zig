//! Owned Placement Of The Executable And Its Library Graph

const std = @import("std");

const Layout = @import("shared").elf.types.dynamic.Layout;

pub const Biases = struct {
    Executable: u64,
    Libraries: []const u64,
};

pub const Interval = struct {
    Start: u64,
    End: u64,
};

pub const Placement = struct {
    Allocator: std.mem.Allocator,
    Executable: Layout,
    Libraries: []Layout,
    Pages: u64,

    pub fn deinit(self: *Placement) void {
        for (self.Libraries) |*library| library.Image.deinit();
        self.Allocator.free(self.Libraries);
        self.Executable.Image.deinit();
        self.Libraries = &.{};
        self.Pages = 0;
    }
};
