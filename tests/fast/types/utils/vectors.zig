//! Common And Utility Check Fixtures

pub const Fixed26RoundingCase = struct {
    Raw: i32,
    Floor: i32,
    Ceiling: i32,
    Round: i32,
    Fraction: i32,
};

pub const Fixed16RatioCase = struct {
    Numerator: i32,
    Denominator: i32,
    Raw: i32,
};

pub const SquareRootCase = struct {
    Value: u64,
    Root: u32,
};

pub const PagingIndicesCase = struct {
    Address: u64,
    PML4: u9,
    PDPT: u9,
    PD: u9,
    PT: u9,
};

pub const UTF8Case = struct {
    Bytes: []const u8,
    Codepoint: u32,
    Length: u8,
};
