//! Immutable Library Cache Key

const std = @import("std");

const Protection = @import("shared").launch.types.provision.Protection;

pub const Key = struct {
    Digest: [std.crypto.hash.sha2.Sha256.digest_length]u8,
    Protection: Protection,
};
