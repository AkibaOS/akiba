//! Validated Pulse Service Document Ownership

const std = @import("std");

const defaults = @import("pulse").world.constants.defaults;

const Role = @import("shared").launch.types.device.Role;

pub const Job = struct {
    Name: []const u8,
    Binary: []const u8,
    Parameters: []const u8 = &.{},
    After: []const []const u8,
    Enabled: bool = true,
    Required: bool = true,
    Controller: bool = false,
    Device: ?Role = null,
    Restarts: u64 = 0,
    Timeout: u64 = defaults.TIMEOUT_TICKS,
};

pub const Document = struct {
    Arena: std.heap.ArenaAllocator,
    Jobs: []const Job,
    Order: []const usize,

    pub fn deinit(self: *Document) void {
        self.Arena.deinit();
        self.* = undefined;
    }
};
