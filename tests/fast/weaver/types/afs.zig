//! Native Read Only AFS Disk Fixture

const std = @import("std");

pub const Device = struct {
    File: std.fs.File,
    Start: u64,
    CellSize: u32,
    Refuse: bool = false,
};
