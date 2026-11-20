//! AFS Cell Geometry Bound To One Native Partition

const Source = @import("shared").storage.types.sector.Source;

pub const SectorVolume = struct {
    Source: Source,
    FirstLBA: u64,
    LastLBA: u64,
    CellSize: u32,
    TotalCells: u64,
};
