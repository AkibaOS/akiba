//! Resident Immutable Library Page Cache State

const std = @import("std");

const Key = @import("weaver").launch.types.cache.key.Key;

pub const Cache = struct {
    Allocator: std.mem.Allocator,
    Entries: std.AutoArrayHashMapUnmanaged(Key, u64) = .empty,
    Busy: std.atomic.Value(bool) = .init(false),
};
