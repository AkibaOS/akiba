//! Hikari Partition Information

const media = @import("hikari").disk.types.media;

pub const PartitionInfo = struct {
    Media: media.MediaSnapshot,
    StartLBA: u64,
    EndLBA: u64,
};
