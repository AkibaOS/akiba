//! Owned Planned AFS Filesystem

const std = @import("std");

const afs = @import("shared").afs;
const tool = @import("mkafsdisk");

pub const FilesystemPlan = struct {
    Allocator: std.mem.Allocator,
    Manifest: tool.types.manifest.Manifest,
    Tree: tool.types.tree.TreePlan,
    Volume: tool.types.geometry.VolumePlan,
    Spans: []afs.types.volume.SpanDescriptor,

    pub fn deinit(self: *FilesystemPlan) void {
        self.Tree.deinit();
        self.Allocator.free(self.Spans);
        self.Manifest.deinit();
        self.* = undefined;
    }
};
