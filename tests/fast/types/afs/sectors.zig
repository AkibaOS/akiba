//! Synthetic AFS Sector Buffer And Access Trace

const values = @import("tests").fast.constants.afs.sectors;

const VolumeHeader = @import("shared").afs.types.volume.VolumeHeader;

pub const Trace = struct {
    Header: VolumeHeader = .{ .CellSize = values.CELL_BYTES, .TotalCells = values.CELLS },
    Reads: [values.TRACE_CAPACITY]u64 = undefined,
    Count: usize = 0,
    FailAt: ?u64 = null,
};
