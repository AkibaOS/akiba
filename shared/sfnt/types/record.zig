//! SFNT Table Record

pub const TableRecord = struct {
    Tag: u32,
    Offset: u32,
    Length: u32,
};
