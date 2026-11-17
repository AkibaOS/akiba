//! Deterministic Owned AFS Source Collection

const std = @import("std");

const afs = @import("shared").afs;
const tool = @import("mkafsdisk");

const Collection = tool.types.manifest.Collection;
const DirectoryEntries = tool.types.manifest.DirectoryEntries;
const PlanningError = tool.errors.planning.PlanningError;
const SourceEntry = tool.types.manifest.SourceEntry;

pub fn collect(allocator: std.mem.Allocator, source: []const u8) !tool.types.manifest.Manifest {
    var directory = try std.fs.cwd().openDir(source, .{ .iterate = true, .no_follow = true });
    defer directory.close();
    const source_path = try directory.realpathAlloc(allocator, tool.strings.names.ENTRY_CURRENT);
    defer allocator.free(source_path);
    var collection = Collection{
        .Allocator = allocator,
        .Timestamp = std.math.cast(u64, std.time.timestamp()) orelse return PlanningError.Overflow,
    };
    defer collection.deinit();
    try appendEntry(&collection, .{
        .ParentNodeId = afs.constants.nodes.ORIGIN,
        .NodeId = afs.constants.nodes.ORIGIN_STACK,
        .Identity = tool.strings.names.ORIGIN_IDENTITY,
        .Path = source_path,
        .Kind = .Stack,
    });
    try collectDirectory(&collection, directory, source_path, afs.constants.nodes.ORIGIN_STACK);
    return .{
        .Allocator = allocator,
        .Entries = try collection.Entries.toOwnedSlice(allocator),
        .UnitCount = collection.UnitCount,
        .StackCount = collection.StackCount,
        .NextNodeId = collection.NextNodeId,
    };
}

pub fn takeNodeId(next_node_id: *u32) PlanningError!u32 {
    if (next_node_id.* == std.math.maxInt(u32)) return PlanningError.Overflow;
    const node_id = next_node_id.*;
    next_node_id.* += 1;
    return node_id;
}

pub fn incrementCount(count: *u32) PlanningError!void {
    if (count.* == std.math.maxInt(u32)) return PlanningError.Overflow;
    count.* += 1;
}

fn collectDirectory(collection: *Collection, directory: std.fs.Dir, path: []const u8, parent: u32) anyerror!void {
    var entries = try readEntries(collection.Allocator, directory);
    defer entries.deinit();
    for (entries.Entries) |entry| try collectEntry(collection, directory, path, parent, entry);
}

fn readEntries(allocator: std.mem.Allocator, directory: std.fs.Dir) !DirectoryEntries {
    var entries: std.ArrayList(SourceEntry) = .empty;
    defer entries.deinit(allocator);
    errdefer for (entries.items) |entry| allocator.free(entry.Identity);
    var iterator = directory.iterate();
    while (try iterator.next()) |entry| {
        if (entry.name.len != 0 and entry.name[0] == tool.strings.names.ENTRY_CURRENT[0]) continue;
        try tool.catalog.pack.validateIdentity(entry.name, false);
        if (entry.kind != .directory and entry.kind != .file) return PlanningError.UnsupportedSource;
        const identity = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(identity);
        try entries.append(allocator, .{ .Identity = identity, .Kind = entry.kind });
    }
    std.mem.sort(SourceEntry, entries.items, {}, lessSourceEntry);
    return .{ .Allocator = allocator, .Entries = try entries.toOwnedSlice(allocator) };
}

fn lessSourceEntry(_: void, left: SourceEntry, right: SourceEntry) bool {
    return std.mem.order(u8, left.Identity, right.Identity) == .lt;
}

fn collectEntry(collection: *Collection, directory: std.fs.Dir, parent_path: []const u8, parent: u32, source: SourceEntry) anyerror!void {
    const path = try std.fs.path.join(collection.Allocator, &.{ parent_path, source.Identity });
    defer collection.Allocator.free(path);
    const node_id = try takeNodeId(&collection.NextNodeId);
    if (source.Kind == .directory) {
        var child = try directory.openDir(source.Identity, .{ .iterate = true, .no_follow = true });
        defer child.close();
        try appendEntry(collection, .{
            .ParentNodeId = parent,
            .NodeId = node_id,
            .Identity = source.Identity,
            .Path = path,
            .Kind = .Stack,
        });
        try collectDirectory(collection, child, path, node_id);
        return;
    }
    const file = try directory.openFile(source.Identity, .{});
    defer file.close();
    const metadata = try file.stat();
    if (metadata.kind != .file) return PlanningError.UnsupportedSource;
    _ = try tool.image.geometry.payloadCells(metadata.size);
    try appendEntry(collection, .{
        .ParentNodeId = parent,
        .NodeId = node_id,
        .Identity = source.Identity,
        .Path = path,
        .Kind = .Unit,
        .LogicalSize = metadata.size,
    });
}

fn appendEntry(collection: *Collection, entry: tool.types.catalog.Entry) !void {
    if (collection.Entries.items.len >= std.math.maxInt(u32)) return PlanningError.Overflow;
    switch (entry.Kind) {
        .Stack => try incrementCount(&collection.StackCount),
        .Unit => try incrementCount(&collection.UnitCount),
    }
    const identity = try collection.Allocator.dupe(u8, entry.Identity);
    errdefer collection.Allocator.free(identity);
    const path = try collection.Allocator.dupe(u8, entry.Path);
    errdefer collection.Allocator.free(path);
    var owned = entry;
    owned.Identity = identity;
    owned.Path = path;
    owned.Timestamp = collection.Timestamp;
    try collection.Entries.append(collection.Allocator, owned);
}
