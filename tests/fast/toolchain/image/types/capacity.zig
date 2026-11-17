//! AFS Capacity Regression Fixture Types

const afs = @import("shared").afs;
const tool = @import("mkafsdisk");

pub const VolumeCase = struct {
    TotalCells: u64,
    BitmapBytes: u32,
    BitmapCells: u32,
    IndexStartCell: u32,
    DataStartCell: u32,
    UsedCells: u32,
    FreeCells: u32,
};

pub const DiskCase = struct {
    SizeMiB: u32,
    TotalSectors: u64,
    ProtectiveSectorCount: u32,
    TotalCells: u32,
};

pub const ExactFixture = struct {
    Names: [6][203]u8,
    Entries: [6]tool.types.catalog.Entry,
    Spans: [6]afs.types.volume.SpanDescriptor,
};

pub const DeepFixture = struct {
    Names: [128][180]u8,
    Entries: [128]tool.types.catalog.Entry,
    Spans: [128]afs.types.volume.SpanDescriptor,
};
