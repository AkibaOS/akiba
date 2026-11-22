//! Read The Installed Driver Catalog And Its Selection Policy

const std = @import("std");

const afs = @import("shared").afs;
const install = @import("shared").location.strings.installed.paths;
const letters = @import("shared").afs.constants.service.postman;
const limits = @import("pulse").devices.constants.catalog.limits;
const parse = @import("pulse").devices.catalog.parse;
const policy = @import("pulse").devices.catalog.policy;
const select = @import("pulse").devices.catalog.select;
const unit = @import("shared").launch.service.request;

const Candidate = @import("pulse").devices.types.catalog.records.Candidate;
const Catalog = @import("pulse").devices.types.catalog.records.Catalog;
const Client = @import("shared").afs.types.service.client.Client;
const Entry = @import("shared").afs.types.read.list.Entry;
const Key = @import("shared").device.types.instance.Key;

pub fn load(allocator: std.mem.Allocator, client: Client) !Catalog {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const owned = arena.allocator();
    const files = try directory(owned, client);
    var candidates: std.ArrayList(Candidate) = .empty;
    for (files) |file| {
        if (!std.mem.endsWith(u8, file, install.FLAT_DRIVER_COMPANION)) continue;
        const identity = file[0 .. file.len - install.FLAT_DRIVER_COMPANION.len];
        if (!unit.validIdentity(identity) or !contains(files, identity)) continue;
        const path = try std.fmt.allocPrint(owned, install.FLAT_DRIVER_FORMAT, .{file});
        const bytes = afs.service.client.readWithin(client, owned, path, limits.MAX_DESCRIPTION_BYTES) catch |failure| {
            if (failure == error.TooLarge) continue;
            return failure;
        } orelse continue;
        const description = parse.manifest(owned, bytes) catch |failure| {
            if (failure == error.OutOfMemory) return failure;
            continue;
        };
        try candidates.append(owned, .{ .Identity = identity, .Description = description });
    }
    const overrides = try afs.service.client.readWithin(client, owned, install.FLAT_DRIVER_WORLD, limits.MAX_DESCRIPTION_BYTES);
    const preferences = if (overrides) |bytes| try policy.read(&arena, bytes) else &.{};
    return .{ .Arena = arena, .Candidates = try candidates.toOwnedSlice(owned), .Preferences = preferences };
}

pub fn matching(catalog: *const Catalog, key: Key) ![]const u8 {
    return select.choose(catalog.Candidates, key, policy.preferred(catalog.Preferences, key));
}

fn directory(allocator: std.mem.Allocator, client: Client) ![][]const u8 {
    var names: std.ArrayList([]const u8) = .empty;
    for (0..limits.MAX_DIRECTORY_ENTRIES + 1) |index| {
        var entry: Entry = undefined;
        const reply = try afs.service.client.request(client, letters.LIST, install.SYSTEM_DRIVERS, index, 0, std.mem.asBytes(&entry));
        if (reply.Kind == letters.END and reply.Length == 0) return names.toOwnedSlice(allocator);
        if (reply.Kind != letters.ENTRY or reply.Length != @sizeOf(Entry) or entry.Length > entry.Identity.len or index == limits.MAX_DIRECTORY_ENTRIES) return error.InvalidCatalog;
        if (entry.Kind == .Unit) try names.append(allocator, try std.unicode.utf16LeToUtf8Alloc(allocator, entry.Identity[0..entry.Length]));
    }
    return error.InvalidCatalog;
}

fn contains(names: [][]const u8, identity: []const u8) bool {
    for (names) |name| {
        if (std.mem.eql(u8, name, identity)) return true;
    }
    return false;
}
