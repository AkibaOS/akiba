//! SFNT Parse Errors

pub const ParseError = error{
    UnexpectedEnd,
    InvalidSignature,
    UnsupportedOutlines,
    UnsupportedCollection,
    TooManyTables,
    TableMissing,
    TableOutOfBounds,
};
