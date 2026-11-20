//! Hikari Partition Information

const buffer = @import("hikari").efi.types.buffer.claims;
const media = @import("hikari").disk.types.media;
const parser = @import("hikari").disk.types.parser;

pub const PartitionInfo = struct {
    Media: media.MediaSnapshot,
    StartLBA: u64,
    EndLBA: u64,
};

pub const Discovery = struct {
    Parser: parser.Parser,
    Handles: buffer.PoolClaim = .{},
};
