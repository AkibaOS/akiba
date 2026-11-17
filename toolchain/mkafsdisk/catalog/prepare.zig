//! Complete AFS Manifest Tree Volume And Span Planning

const std = @import("std");

const afs = @import("shared").afs;
const tool = @import("mkafsdisk");

pub fn prepare(allocator: std.mem.Allocator, source: []const u8, partition_size_bytes: u64) !tool.types.filesystem.FilesystemPlan {
    var manifest = try tool.catalog.collect.collect(allocator, source);
    errdefer manifest.deinit();
    var tree = try tool.catalog.pack.pack(allocator, manifest.Entries);
    errdefer tree.deinit();
    var payload_cells: u64 = 0;
    for (manifest.Entries) |entry| {
        if (entry.Kind != .Unit) continue;
        const cells = try tool.image.geometry.payloadCells(entry.LogicalSize);
        payload_cells = std.math.add(u64, payload_cells, cells) catch return tool.errors.planning.PlanningError.Overflow;
    }
    const total_cells = partition_size_bytes / afs.constants.sizes.DEFAULT_CELL_SIZE;
    const volume = try tool.image.geometry.volume(total_cells, tree.Header.TotalNodes, payload_cells);
    const spans = try tool.image.geometry.spans(allocator, manifest.Entries, volume);
    return .{ .Allocator = allocator, .Manifest = manifest, .Tree = tree, .Volume = volume, .Spans = spans };
}
