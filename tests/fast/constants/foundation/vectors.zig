//! Common And Utility Check Values

const fixtures = @import("tests").fast.types.foundation.vectors;

pub const FIXED26_ROUNDING_CASES = [_]fixtures.Fixed26RoundingCase{
    .{ .Raw = -97, .Floor = -2, .Ceiling = -1, .Round = -2, .Fraction = 31 },
    .{ .Raw = -96, .Floor = -2, .Ceiling = -1, .Round = -1, .Fraction = 32 },
    .{ .Raw = -95, .Floor = -2, .Ceiling = -1, .Round = -1, .Fraction = 33 },
    .{ .Raw = -65, .Floor = -2, .Ceiling = -1, .Round = -1, .Fraction = 63 },
    .{ .Raw = -64, .Floor = -1, .Ceiling = -1, .Round = -1, .Fraction = 0 },
    .{ .Raw = -1, .Floor = -1, .Ceiling = 0, .Round = 0, .Fraction = 63 },
    .{ .Raw = 0, .Floor = 0, .Ceiling = 0, .Round = 0, .Fraction = 0 },
    .{ .Raw = 1, .Floor = 0, .Ceiling = 1, .Round = 0, .Fraction = 1 },
    .{ .Raw = 31, .Floor = 0, .Ceiling = 1, .Round = 0, .Fraction = 31 },
    .{ .Raw = 32, .Floor = 0, .Ceiling = 1, .Round = 1, .Fraction = 32 },
    .{ .Raw = 33, .Floor = 0, .Ceiling = 1, .Round = 1, .Fraction = 33 },
    .{ .Raw = 64, .Floor = 1, .Ceiling = 1, .Round = 1, .Fraction = 0 },
    .{ .Raw = 65, .Floor = 1, .Ceiling = 2, .Round = 1, .Fraction = 1 },
    .{ .Raw = 96, .Floor = 1, .Ceiling = 2, .Round = 2, .Fraction = 32 },
};

pub const FIXED16_RATIO_CASES = [_]fixtures.Fixed16RatioCase{
    .{ .Numerator = 0, .Denominator = 7, .Raw = 0 },
    .{ .Numerator = 1, .Denominator = 2, .Raw = 32768 },
    .{ .Numerator = -1, .Denominator = 2, .Raw = -32768 },
    .{ .Numerator = 1, .Denominator = 3, .Raw = 21845 },
    .{ .Numerator = -1, .Denominator = 3, .Raw = -21845 },
    .{ .Numerator = 2, .Denominator = 3, .Raw = 43691 },
    .{ .Numerator = -2, .Denominator = 3, .Raw = -43691 },
    .{ .Numerator = 1, .Denominator = 131072, .Raw = 1 },
    .{ .Numerator = -1, .Denominator = 131072, .Raw = -1 },
    .{ .Numerator = 32767, .Denominator = 1, .Raw = 2147418112 },
    .{ .Numerator = -32768, .Denominator = 1, .Raw = -2147483648 },
    .{ .Numerator = 2147483647, .Denominator = 2147483647, .Raw = 65536 },
    .{ .Numerator = -2147483648, .Denominator = 2147483647, .Raw = -65536 },
};

pub const FIXED16_NEGATIVE_RATIO_CASES = [_]fixtures.Fixed16RatioCase{
    .{ .Numerator = 0, .Denominator = -2, .Raw = 0 },
    .{ .Numerator = 1, .Denominator = -1, .Raw = -65536 },
    .{ .Numerator = 1, .Denominator = -2, .Raw = -32768 },
    .{ .Numerator = -1, .Denominator = -2, .Raw = 32768 },
    .{ .Numerator = 2, .Denominator = -3, .Raw = -43691 },
    .{ .Numerator = -2, .Denominator = -3, .Raw = 43691 },
    .{ .Numerator = 1, .Denominator = -131072, .Raw = -1 },
    .{ .Numerator = -1, .Denominator = -131072, .Raw = 1 },
    .{ .Numerator = 2147483647, .Denominator = -2147483647, .Raw = -65536 },
    .{ .Numerator = -2147483648, .Denominator = -2147483648, .Raw = 65536 },
    .{ .Numerator = 16384, .Denominator = -2147483648, .Raw = -1 },
    .{ .Numerator = -16384, .Denominator = -2147483648, .Raw = 1 },
};

pub const SQUARE_ROOT_CASES = [_]fixtures.SquareRootCase{
    .{ .Value = 0, .Root = 0 },
    .{ .Value = 1, .Root = 1 },
    .{ .Value = 2, .Root = 1 },
    .{ .Value = 3, .Root = 1 },
    .{ .Value = 4, .Root = 2 },
    .{ .Value = 8, .Root = 2 },
    .{ .Value = 9, .Root = 3 },
    .{ .Value = 15, .Root = 3 },
    .{ .Value = 16, .Root = 4 },
    .{ .Value = 17, .Root = 4 },
    .{ .Value = 0xffffffff, .Root = 65535 },
    .{ .Value = 0x100000000, .Root = 65536 },
    .{ .Value = 0x100000001, .Root = 65536 },
    .{ .Value = 0xfffffffe00000000, .Root = 0xfffffffe },
    .{ .Value = 0xfffffffe00000001, .Root = 0xffffffff },
    .{ .Value = 0xffffffffffffffff, .Root = 0xffffffff },
};

pub const PAGING_INDICES_CASES = [_]fixtures.PagingIndicesCase{
    .{ .Address = 0, .PML4 = 0, .PDPT = 0, .PD = 0, .PT = 0 },
    .{ .Address = 0xfff, .PML4 = 0, .PDPT = 0, .PD = 0, .PT = 0 },
    .{ .Address = 0x0000008080604123, .PML4 = 1, .PDPT = 2, .PD = 3, .PT = 4 },
    .{ .Address = 0x00007fffffffffff, .PML4 = 255, .PDPT = 511, .PD = 511, .PT = 511 },
    .{ .Address = 0xffff800000000000, .PML4 = 256, .PDPT = 0, .PD = 0, .PT = 0 },
    .{ .Address = 0xffff808080604fed, .PML4 = 257, .PDPT = 2, .PD = 3, .PT = 4 },
    .{ .Address = 0xffffffffffffffff, .PML4 = 511, .PDPT = 511, .PD = 511, .PT = 511 },
};

pub const UTF8_VALID_CASES = [_]fixtures.UTF8Case{
    .{ .Bytes = &.{0x00}, .Codepoint = 0x00, .Length = 1 },
    .{ .Bytes = &.{0x41}, .Codepoint = 0x41, .Length = 1 },
    .{ .Bytes = &.{0x7f}, .Codepoint = 0x7f, .Length = 1 },
    .{ .Bytes = &.{ 0xc2, 0x80 }, .Codepoint = 0x80, .Length = 2 },
    .{ .Bytes = &.{ 0xdf, 0xbf }, .Codepoint = 0x7ff, .Length = 2 },
    .{ .Bytes = &.{ 0xe0, 0xa0, 0x80 }, .Codepoint = 0x800, .Length = 3 },
    .{ .Bytes = &.{ 0xed, 0x9f, 0xbf }, .Codepoint = 0xd7ff, .Length = 3 },
    .{ .Bytes = &.{ 0xee, 0x80, 0x80 }, .Codepoint = 0xe000, .Length = 3 },
    .{ .Bytes = &.{ 0xef, 0xbf, 0xbf }, .Codepoint = 0xffff, .Length = 3 },
    .{ .Bytes = &.{ 0xf0, 0x90, 0x80, 0x80 }, .Codepoint = 0x10000, .Length = 4 },
    .{ .Bytes = &.{ 0xf0, 0x9f, 0x99, 0x82 }, .Codepoint = 0x1f642, .Length = 4 },
    .{ .Bytes = &.{ 0xf4, 0x8f, 0xbf, 0xbf }, .Codepoint = 0x10ffff, .Length = 4 },
};

pub const UTF8_INVALID_LEAD_CASES = [_]fixtures.UTF8Case{
    .{ .Bytes = &.{0x80}, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{0xbf}, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xc0, 0xaf }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xc1, 0xbf }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xf5, 0x80, 0x80, 0x80 }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{0xfe}, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xff, 0x41 }, .Codepoint = 0xfffd, .Length = 1 },
};

pub const UTF8_TRUNCATED_CASES = [_]fixtures.UTF8Case{
    .{ .Bytes = &.{0xc2}, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{0xe2}, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xe2, 0x82 }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{0xf0}, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xf0, 0x90 }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xf0, 0x90, 0x80 }, .Codepoint = 0xfffd, .Length = 1 },
};

pub const UTF8_INVALID_CONTINUATION_CASES = [_]fixtures.UTF8Case{
    .{ .Bytes = &.{ 0xc2, 0x41 }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xe2, 0x28, 0xa1 }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xe2, 0x82, 0x41 }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xf0, 0x28, 0x8c, 0xbc }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xf0, 0x90, 0x28, 0xbc }, .Codepoint = 0xfffd, .Length = 1 },
    .{ .Bytes = &.{ 0xf0, 0x90, 0x80, 0x41 }, .Codepoint = 0xfffd, .Length = 1 },
};

pub const UTF8_OVERLONG_CASES = [_]fixtures.UTF8Case{
    .{ .Bytes = &.{ 0xe0, 0x80, 0x80 }, .Codepoint = 0xfffd, .Length = 3 },
    .{ .Bytes = &.{ 0xe0, 0x9f, 0xbf }, .Codepoint = 0xfffd, .Length = 3 },
    .{ .Bytes = &.{ 0xf0, 0x80, 0x80, 0x80 }, .Codepoint = 0xfffd, .Length = 4 },
    .{ .Bytes = &.{ 0xf0, 0x8f, 0xbf, 0xbf }, .Codepoint = 0xfffd, .Length = 4 },
};

pub const UTF8_SURROGATE_CASES = [_]fixtures.UTF8Case{
    .{ .Bytes = &.{ 0xed, 0xa0, 0x80 }, .Codepoint = 0xfffd, .Length = 3 },
    .{ .Bytes = &.{ 0xed, 0xbf, 0xbf }, .Codepoint = 0xfffd, .Length = 3 },
};

pub const UTF8_OUT_OF_RANGE_CASES = [_]fixtures.UTF8Case{
    .{ .Bytes = &.{ 0xf4, 0x90, 0x80, 0x80 }, .Codepoint = 0xfffd, .Length = 4 },
    .{ .Bytes = &.{ 0xf4, 0xbf, 0xbf, 0xbf }, .Codepoint = 0xfffd, .Length = 4 },
};
