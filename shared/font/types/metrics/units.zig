//! Font Metrics

pub const GlyphMetrics = struct {
    AdvanceWidth: u16,
    LeftSideBearing: i16,
};

pub const FaceMetrics = struct {
    UnitsPerEm: u16,
    Ascender: i16,
    Descender: i16,
    LineGap: i16,
};
