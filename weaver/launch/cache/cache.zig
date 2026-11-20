//! Serialize Cache Publication And Release Retained Handles

const std = @import("std");

const launch = @import("weaver").launch;

const Cache = launch.types.cache.Cache;
const Channel = launch.types.request.Channel;
const Key = launch.types.cache.Key;
const Protection = @import("shared").launch.types.provision.Protection;
const RequestError = launch.errors.request.RequestError;

pub fn begin(cache: *Cache) RequestError!usize {
    if (cache.Busy.swap(true, .acquire)) return error.CacheBusy;
    return cache.Entries.count();
}

pub fn finish(cache: *Cache, boundary: usize, committed: bool) void {
    if (!committed) {
        while (cache.Entries.count() > boundary) cache.Entries.swapRemoveAt(cache.Entries.count() - 1);
    }
    cache.Busy.store(false, .release);
}

pub fn key(bytes: []const u8, protection: Protection) Key {
    var identity: Key = .{ .Digest = undefined, .Protection = protection };
    std.crypto.hash.sha2.Sha256.hash(bytes, &identity.Digest, .{});
    return identity;
}

pub fn evict(cache: *Cache, channel: Channel) RequestError!void {
    if (channel.Ticket == 0) return error.InvalidTicket;
    const boundary = try begin(cache);
    defer finish(cache, boundary, true);
    while (cache.Entries.count() != 0) {
        const last = cache.Entries.count() - 1;
        _ = try launch.transaction.stage.invoke(channel, .Forget, cache.Entries.values()[last], .ReadOnly);
        cache.Entries.swapRemoveAt(last);
    }
    cache.Entries.deinit(cache.Allocator);
    cache.Entries = .empty;
}
