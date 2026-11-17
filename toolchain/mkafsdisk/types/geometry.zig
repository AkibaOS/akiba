//! Checked Disk And AFS Volume Plans

pub const DiskPlan = struct {
    TotalBytes: u64,
    TotalSectors: u64,
    EspStartLBA: u64,
    EspEndLBA: u64,
    AfsStartLBA: u64,
    AfsEndLBA: u64,
    PrimaryHeaderLBA: u64,
    PrimaryEntriesLBA: u64,
    BackupHeaderLBA: u64,
    BackupEntriesLBA: u64,
    FirstUsableLBA: u64,
    LastUsableLBA: u64,
    PartitionStartByte: u64,
    PartitionSizeBytes: u64,
    TotalCells: u32,
    ProtectiveSectorCount: u32,
};

pub const VolumePlan = struct {
    TotalCells: u32,
    BitmapBytes: u32,
    BitmapCells: u32,
    AllocationMapStartCell: u32,
    AllocationMapSize: u32,
    IndexStartCell: u32,
    IndexCells: u32,
    DataStartCell: u32,
    UsedCells: u32,
    FreeCells: u32,
};
