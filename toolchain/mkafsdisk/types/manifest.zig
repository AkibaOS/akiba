//! Owned AFS Source Manifest

const std = @import("std");

const afs = @import("shared").afs;
const catalog = @import("mkafsdisk").types.catalog;

pub const SourceEntry = struct {
    Identity: []u8,
    Kind: std.fs.File.Kind,
};

pub const DirectoryEntries = struct {
    Allocator: std.mem.Allocator,
    Entries: []SourceEntry,

    pub fn deinit(self: *DirectoryEntries) void {
        for (self.Entries) |entry| self.Allocator.free(entry.Identity);
        self.Allocator.free(self.Entries);
        self.* = undefined;
    }
};

pub const Collection = struct {
    Allocator: std.mem.Allocator,
    Entries: std.ArrayList(catalog.Entry) = .empty,
    UnitCount: u32 = 0,
    StackCount: u32 = 0,
    NextNodeId: u32 = afs.constants.nodes.FIRST_USER,
    Timestamp: u64,

    pub fn deinit(self: *Collection) void {
        for (self.Entries.items) |entry| {
            self.Allocator.free(entry.Identity);
            self.Allocator.free(entry.Path);
        }
        self.Entries.deinit(self.Allocator);
        self.* = undefined;
    }
};

pub const Manifest = struct {
    Allocator: std.mem.Allocator,
    Entries: []catalog.Entry,
    UnitCount: u32,
    StackCount: u32,
    NextNodeId: u32,

    pub fn deinit(self: *Manifest) void {
        for (self.Entries) |entry| {
            self.Allocator.free(entry.Identity);
            self.Allocator.free(entry.Path);
        }
        self.Allocator.free(self.Entries);
        self.* = undefined;
    }
};
