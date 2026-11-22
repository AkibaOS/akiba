//! Collect One Stable System Snapshot For Each ELF Dependency

const std = @import("std");

const elf = @import("shared").elf;
const library = @import("weaver").library;

const Graph = library.types.graph.Graph;
const Index = library.types.graph.Index;
const Library = library.types.library.Library;
const LibraryError = library.errors.library.LibraryError;
const Metadata = elf.types.dynamic.Metadata;
const Source = library.types.source.Source;

pub fn collect(allocator: std.mem.Allocator, source: Source, executable: []const u8) LibraryError!Graph {
    const bytes = try allocator.dupe(u8, executable);
    errdefer allocator.free(bytes);
    if ((try elf.read.header.read(bytes)).isExecutable()) return .{
        .Allocator = allocator,
        .Executable = bytes,
        .Libraries = try allocator.alloc(Library, 0),
        .Names = .empty,
    };
    const metadata = try elf.read.dynamic.read(bytes);
    var libraries: std.ArrayList(Library) = .empty;
    defer libraries.deinit(allocator);
    errdefer for (libraries.items) |*snapshot| snapshot.deinit();
    var names: Index = .empty;
    errdefer names.deinit(allocator);

    try addDependencies(allocator, source, metadata, &names, &libraries);
    var next: usize = 0;
    while (next < libraries.items.len) : (next += 1) {
        try addDependencies(allocator, source, libraries.items[next].Metadata, &names, &libraries);
    }
    return .{ .Allocator = allocator, .Executable = bytes, .Libraries = try libraries.toOwnedSlice(allocator), .Names = names };
}

fn addDependencies(allocator: std.mem.Allocator, source: Source, metadata: Metadata, names: *Index, libraries: *std.ArrayList(Library)) LibraryError!void {
    for (metadata.Entries) |entry| {
        if (entry.Tag != elf.constants.dynamic.NEEDED) continue;
        const name = try metadata.string(entry.Value);
        if (names.contains(name)) continue;
        var snapshot = try library.load.open.open(allocator, source, name);
        errdefer snapshot.deinit();
        try libraries.ensureUnusedCapacity(allocator, 1);
        try names.putNoClobber(allocator, snapshot.Identity, libraries.items.len);
        libraries.appendAssumeCapacity(snapshot);
    }
}
