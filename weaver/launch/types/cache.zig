//! Resident Immutable Library Page Cache

const std = @import("std");

const Protection = @import("shared").launch.types.provision.Protection;

pub const Key = struct {
    Digest: [std.crypto.hash.sha2.Sha256.digest_length]u8,
    Protection: Protection,
};

pub const Cache = struct {
    Allocator: std.mem.Allocator,
    Entries: std.AutoArrayHashMapUnmanaged(Key, u64) = .empty,
    Busy: std.atomic.Value(bool) = .init(false),
};
