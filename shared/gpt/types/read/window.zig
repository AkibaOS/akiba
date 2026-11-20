//! Checked GPT Sector And Table Geometry

const bounds = @import("shared").boot.constants.volume;

pub const Window = struct {
    DiskGUID: [bounds.GUID_BYTES]u8,
    FirstUsableLBA: u64,
    LastUsableLBA: u64,
    TableLBA: u64,
    TableBytes: u64,
    TableSectors: u64,
    TableCRC: u32,
    EntryBytes: u32,
};
