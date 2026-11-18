//! SFNT Parse Errors

pub const ParseError = error{
    UnexpectedEnd,
    InvalidSignature,
    UnsupportedOutlines,
    UnsupportedCollection,
    TableMissing,
    TableOutOfBounds,
};
