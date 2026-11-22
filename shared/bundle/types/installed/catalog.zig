//! Installed Candidates And Owned Catalog Storage

const std = @import("std");

const Descriptor = @import("shared").bundle.types.manifest.descriptor.Descriptor;
const ResolveError = @import("shared").bundle.errors.installed.resolve.ResolveError;

pub const Candidate = struct {
    Identity: []const u8,
    State: State,
};

pub const State = union(enum) {
    Description: Descriptor,
    Failure: ResolveError,
};

pub const Catalog = struct {
    Arena: std.heap.ArenaAllocator,
    Candidates: []const Candidate,

    pub fn deinit(self: *Catalog) void {
        self.Arena.deinit();
        self.* = undefined;
    }
};
