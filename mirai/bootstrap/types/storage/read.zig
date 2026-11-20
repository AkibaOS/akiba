//! Requested Boot Unit And Detached Owned Image

const std = @import("std");

const Location = @import("shared").ahci.types.discover.selection.Location;
const Volume = @import("shared").boot.types.volume.Volume;

pub const Path = struct {
    Parents: []const []const u8,
    Unit: []const u8,
};

pub const Image = struct {
    Location: Location,
    Bytes: []u8,
};

pub const Request = struct {
    Volume: Volume,
    Path: Path,
    Allocator: std.mem.Allocator,
    Bytes: ?[]u8 = null,
};
