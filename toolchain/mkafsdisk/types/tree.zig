//! Owned AFS Bulk Catalog Plan

const std = @import("std");

const afs = @import("shared").afs;

pub const Level = struct {
    Start: usize,
    Count: usize,
    Height: u8,
};

pub const RecordPlan = struct {
    EntryIndex: usize,
    ChildNode: u32 = 0,
    Length: usize,
};

pub const NodePlan = struct {
    Number: u32,
    Height: u8,
    ForwardLink: u32 = 0,
    BackwardLink: u32 = 0,
    Records: []RecordPlan,
};

pub const TreePlan = struct {
    Allocator: std.mem.Allocator,
    Nodes: []NodePlan,
    Header: afs.types.btree.records.HeaderRecord,

    pub fn deinit(self: *TreePlan) void {
        for (self.Nodes) |node| self.Allocator.free(node.Records);
        self.Allocator.free(self.Nodes);
        self.* = undefined;
    }
};
