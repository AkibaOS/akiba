//! Rendering Regression Types

const constants = @import("tests").fast.constants.render;

pub const TableFixture = struct {
    Tag: u32,
    Bytes: []const u8,
};

pub const SFNTFixture = struct {
    Data: [constants.BINARY_CAPACITY]u8,
    Length: usize,
};

pub const GlyphFixture = struct {
    Data: [constants.BINARY_CAPACITY]u8,
    Loca: [constants.LOCATION_CAPACITY]u8,
};

pub const CoverageRow = struct {
    X: i32,
    Y: i32,
    Length: usize,
    Values: [constants.CAPTURE_COLUMNS]u8,
};

pub const CoverageCapture = struct {
    Rows: [constants.CAPTURE_ROWS]CoverageRow,
    Count: usize,
    Overflow: bool,
};

pub const GuardedPixels = struct {
    Prefix: [constants.GUARD_WORDS]u32,
    Pixels: [constants.SMALL_PIXELS]u32,
    Suffix: [constants.GUARD_WORDS]u32,
};

pub const GuardedFrame = struct {
    Prefix: [constants.GUARD_WORDS]u32,
    Pixels: [constants.FRAME_PIXELS]u32,
    Suffix: [constants.GUARD_WORDS]u32,
};
