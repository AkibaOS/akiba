//! Hikari Partition Information

const buffer = @import("hikari").efi.types.buffer.claims;
const media = @import("hikari").disk.types.media;
const parser = @import("hikari").disk.types.parser;
const volume = @import("shared").boot.types.volume;

const Transport = @import("shared").boot.types.transport.Transport;

pub const PartitionInfo = struct {
    Media: media.MediaSnapshot,
    Volume: volume.Volume,
    Transport: Transport = .Unknown,
};

pub const Discovery = struct {
    Parser: parser.Parser,
    Handles: buffer.PoolClaim = .{},
};
