//! Character Map Layout

pub const SegmentLayout = struct {
    Count: usize,
    EndCodes: usize,
    StartCodes: usize,
    Deltas: usize,
    RangeOffsets: usize,
    Glyphs: usize,
};
