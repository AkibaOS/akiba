//! Hikari Partition Information

const buffer = @import("hikari").efi.types.buffer.claims;
const media = @import("hikari").disk.types.media;
const parser = @import("hikari").disk.types.parser;
const volume = @import("shared").boot.types.volume;

pub const PartitionInfo = struct {
    Media: media.MediaSnapshot,
    Volume: volume.Volume,
};

pub const Discovery = struct {
    Parser: parser.Parser,
    Handles: buffer.PoolClaim = .{},
};
