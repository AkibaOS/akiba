//! Parsed Device Driver Description And Candidate

const std = @import("std");

const Key = @import("shared").device.types.instance.Key;
const Kind = @import("shared").device.types.instance.Kind;

pub const Selector = struct {
    Kind: Kind,
    Location: ?u64 = null,
};

pub const Descriptor = struct {
    Match: Selector,
};

pub const Candidate = struct {
    Identity: []const u8,
    Description: Descriptor,
};

pub const Preference = struct {
    Device: Key,
    Identity: []const u8,
};

pub const Catalog = struct {
    Arena: std.heap.ArenaAllocator,
    Candidates: []const Candidate,
    Preferences: []const Preference,

    pub fn deinit(self: *Catalog) void {
        self.Arena.deinit();
        self.* = undefined;
    }
};

pub const Selection = struct {
    Instance: u64,
    Identity: []const u8,
};
