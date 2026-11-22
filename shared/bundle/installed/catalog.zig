//! List Bounded Candidates Without Reading Every Executable

const std = @import("std");

const limits = @import("shared").bundle.constants.contract;
const location = @import("shared").location.installed.resolve;
const resolve = @import("shared").bundle.installed.resolve;

const Candidate = @import("shared").bundle.types.installed.catalog.Candidate;
const Catalog = @import("shared").bundle.types.installed.catalog.Catalog;
const CatalogError = @import("shared").bundle.errors.installed.resolve.CatalogError;
const Descriptor = @import("shared").bundle.types.manifest.descriptor.Descriptor;
const Entry = @import("shared").afs.types.read.list.Entry;
const Reader = @import("shared").bundle.types.installed.reader.Reader;
const ResolveError = @import("shared").bundle.errors.installed.resolve.ResolveError;
const Scope = @import("shared").location.types.installed.location.Scope;

pub fn scan(reader: Reader, allocator: std.mem.Allocator, scope: Scope) CatalogError!Catalog {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const owned = arena.allocator();
    var candidates: std.ArrayList(Candidate) = .empty;
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    defer seen.deinit(allocator);
    const directory = location.scopePath(scope);
    const suffix = location.suffix(location.scopeKind(scope));
    for (0..limits.MAX_DIRECTORY_ENTRIES + 1) |index| {
        const entry = (try reader.List(reader.Context, directory, index)) orelse
            return .{ .Arena = arena, .Candidates = candidates.items };
        if (index == limits.MAX_DIRECTORY_ENTRIES) return error.CatalogTooLarge;
        if (entry.Length == 0 or entry.Length > entry.Identity.len) return error.InvalidCatalog;
        var name: [@as(Entry, undefined).Identity.len]u8 = undefined;
        for (entry.Identity[0..entry.Length], name[0..entry.Length]) |code, *character| {
            character.* = std.math.cast(u8, code) orelse 0;
        }
        const spelling = name[0..entry.Length];
        if (!std.mem.endsWith(u8, spelling, suffix)) continue;
        const id = spelling[0 .. spelling.len - suffix.len];
        if (!location.validIdentity(id)) continue;
        const identity = try owned.dupe(u8, id);
        const result = try seen.getOrPut(allocator, identity);
        if (result.found_existing) return error.InvalidCatalog;
        const description = inspect(reader, allocator, scope, identity, entry) catch |failure| {
            if (failure == error.ReadFailed or failure == error.MissingStack or failure == error.OutOfMemory) return failure;
            try candidates.append(owned, .{ .Identity = identity, .State = .{ .Failure = failure } });
            continue;
        };
        try candidates.append(owned, .{ .Identity = identity, .State = .{ .Description = description } });
    }
    unreachable;
}

fn inspect(reader: Reader, allocator: std.mem.Allocator, scope: Scope, identity: []const u8, entry: Entry) ResolveError!Descriptor {
    if (entry.Kind != .Stack) return error.WrongBundleKind;
    const description = try resolve.describe(reader, allocator, scope, identity);
    try resolve.checkBinary(reader, scope, identity);
    return description;
}
