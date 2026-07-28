//! Font Errors

pub const FontError = error{
    UnexpectedEnd,
    InvalidSignature,
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
