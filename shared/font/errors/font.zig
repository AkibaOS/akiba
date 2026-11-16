//! Font Errors

pub const FontError = error{
    UnexpectedEnd,
    InvalidSignature,
    InvalidUnitsPerEm,
    UnsupportedOutlines,
    UnsupportedCollection,
    TooManyTables,
    TableMissing,
    TableOutOfBounds,
    OutlineTooComplex,
    ComponentDepthExceeded,
    UnsupportedCharacterMap,
    GlyphOutOfRange,
};
