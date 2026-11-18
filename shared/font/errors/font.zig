//! Font Errors

pub const FontError = error{
    UnexpectedEnd,
    InvalidSignature,
    InvalidUnitsPerEm,
    InvalidOutline,
    UnsupportedOutlines,
    UnsupportedCollection,
    TableMissing,
    TableOutOfBounds,
    OutlineTooComplex,
    ComponentDepthExceeded,
    UnsupportedCharacterMap,
    GlyphOutOfRange,
};
