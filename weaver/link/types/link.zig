//! Owned Writes For A Checked Native Placement

const std = @import("std");

const Placement = @import("weaver").image.types.layout.Placement;
const Writes = @import("shared").elf.types.relocation.Plan;

pub const Exports = std.StringHashMapUnmanaged(?usize);
pub const Direct = std.AutoHashMapUnmanaged(usize, void);

pub const Plan = struct {
    Allocator: std.mem.Allocator,
    Placement: *const Placement,
    Executable: Writes,
    Libraries: []Writes,

    pub fn deinit(self: *Plan) void {
        self.Executable.deinit();
        for (self.Libraries) |*library| library.deinit();
        self.Allocator.free(self.Libraries);
        self.Libraries = &.{};
    }
};
