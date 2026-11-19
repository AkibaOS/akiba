//! Disk Image Integration Types

const std = @import("std");

const afs = @import("shared").afs;
const constants = @import("tests").constants.image;

pub const PackingProgress = struct {
    Directory: std.fs.Dir,
    Next: u32 = 0,
};

pub const FileDevice = struct {
    File: std.fs.File,
    PartitionStart: u64,
    CellSize: u32,
};

pub const AFSImage = struct {
    Header: afs.types.volume.VolumeHeader,
    Leaf: [constants.CELL_BYTES]u8,
    Device: FileDevice,
};
