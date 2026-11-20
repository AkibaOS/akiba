//! Read Only AFS Cell Fixture State

pub const LibraryCells = struct {
    Bytes: []const u8,
    Identity: []const u8,
    Missing: bool,
    PayloadCells: u32,
};
