//! World Lexical Token Kinds

pub const Kind = enum { Word, String, Equal, Open, Close, Annotation, EndAnnotation, End, Omit, Eof };

pub const Token = struct {
    Kind: Kind,
    Text: []const u8 = &.{},
    Separated: bool = false,
};
