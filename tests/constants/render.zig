//! Rendering Regression Fixtures

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const raster = @import("shared").raster;

const Color = graphics.types.color.Color;
const Point = font.types.outline.Point;

pub const BINARY_CAPACITY: usize = 4096;
pub const LOCATION_CAPACITY: usize = 64;
pub const CAPTURE_ROWS: usize = 8;
pub const CAPTURE_COLUMNS: usize = raster.constants.limits.MAX_ROW_WIDTH + 2;
pub const GUARD_WORDS: usize = 4;
pub const SMALL_PIXELS: usize = 2048;
pub const FRAME_WIDTH: u32 = 480;
pub const FRAME_HEIGHT: u32 = 128;
pub const FRAME_STRIDE: u32 = 484;
pub const FRAME_PIXELS: usize = FRAME_STRIDE * FRAME_HEIGHT;
pub const GUARD_PIXEL: u32 = 0xD3A59C7E;
pub const UNTOUCHED_PIXEL: u32 = 0x6B192E47;
pub const BLEND_BACKGROUND = Color.rgb(20, 100, 240);
pub const BLEND_FOREGROUND = Color.rgb(220, 20, 40);
pub const RULE_X: i32 = 6;
pub const RULE_Y: i32 = 90;
pub const TRAIL_BASELINE: i32 = 24;

pub const SFNT_VERSION: u32 = 0x00010000;
pub const SFNT_GROWTH_TABLES: u16 = 65;
pub const RASTER_HIGH_ORIGIN: i32 = 0x40000000;
pub const HEAD_TAG: u32 = 0x68656164;
pub const MAXP_TAG: u32 = 0x6D617870;
pub const HHEA_TAG: u32 = 0x68686561;
pub const HMTX_TAG: u32 = 0x686D7478;
pub const LOCA_TAG: u32 = 0x6C6F6361;
pub const GLYF_TAG: u32 = 0x676C7966;
pub const CMAP_TAG: u32 = 0x636D6170;
pub const HEAD_MAGIC: u32 = 0x5F0F3CF5;
pub const HEAD_OFFSET: usize = 124;
pub const MAXP_OFFSET: usize = 180;
pub const HHEA_OFFSET: usize = 212;
pub const UNITS_OFFSET: usize = HEAD_OFFSET + 18;
pub const MAX_POINTS_OFFSET: usize = MAXP_OFFSET + 6;
pub const MAX_CONTOURS_OFFSET: usize = MAXP_OFFSET + 8;
pub const MAX_COMPOSITE_OFFSET: usize = MAXP_OFFSET + 10;
pub const ENDIAN_BYTES = [_]u8{ 0x81, 0x12, 0x34, 0xFF, 0xFE, 0x89, 0xAB, 0xCD, 0xEF };

pub const RECTANGLE_GLYPH = [_]u8{
    0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x00, 0x40,
    0x00, 0x03, 0x00, 0x00, 0x31, 0x33, 0x35, 0x23, 0x20, 0x20,
    0x40, 0x00,
};
pub const NARROW_GLYPH = [_]u8{
    0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x40,
    0x00, 0x03, 0x00, 0x00, 0x31, 0x33, 0x35, 0x23, 0x10, 0x10,
    0x40, 0x00,
};
pub const SCALED_COMPONENT = [_]u8{
    0xFF, 0xFF, 0x00, 0x20, 0xFF, 0xF0, 0x00, 0x30, 0x00, 0x10,
    0x00, 0x0B, 0x00, 0x01, 0x00, 0x20, 0xFF, 0xF0, 0x20, 0x00,
};
pub const GLYF = RECTANGLE_GLYPH ++ NARROW_GLYPH ++ SCALED_COMPONENT;
pub const LOCA = [_]u8{ 0, 0, 0, 0, 0, 11, 0, 22, 0, 32 };
pub const HMTX = [_]u8{ 0, 32, 0xFF, 0xFE, 0, 64, 0, 3, 0xFF, 0xFC, 0, 5 };
pub const REPEATED_GLYPH = [_]u8{
    0x00, 0x01, 0xFF, 0xF6, 0xFF, 0xF6, 0x00, 0x0A, 0x00, 0x0A,
    0x00, 0x03, 0x00, 0x02, 0xAA, 0xBB, 0x09, 0x03, 0xFF, 0xF6,
    0x00, 0x14, 0x00, 0x00, 0xFF, 0xEC, 0xFF, 0xF6, 0x00, 0x00,
    0x00, 0x14, 0x00, 0x00,
};
pub const REPEATED_LOCA = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 34 };
pub const BYTE_COMPONENT = [_]u8{
    0xFF, 0xFF, 0,    0,    0,    0,    0, 0, 0, 0,
    0x00, 0x02, 0x00, 0x01, 0xFD, 0x05,
};
pub const AXIS_COMPONENT = [_]u8{
    0xFF, 0xFF, 0,    0,    0,    0,    0,    0,    0,    0,
    0x00, 0x43, 0x00, 0x01, 0xFF, 0xFC, 0x00, 0x06, 0x20, 0x00,
    0x60, 0x00,
};
pub const MATRIX_COMPONENT = [_]u8{
    0xFF, 0xFF, 0,    0,    0,    0,    0,    0,    0,    0,
    0x00, 0x83, 0x00, 0x03, 0x00, 0x04, 0xFF, 0xFE, 0x00, 0x00,
    0x40, 0x00, 0xC0, 0x00, 0x00, 0x00,
};
pub const MULTIPLE_COMPONENTS = [_]u8{
    0xFF, 0xFF, 0,    0,    0,    0,    0,    0,    0,    0,
    0x00, 0x23, 0x00, 0x03, 0x00, 0x0A, 0x00, 0x14, 0x00, 0x03,
    0x00, 0x01, 0xFF, 0xFB, 0xFF, 0xFA,
};

pub const CMAP4 = [_]u8{
    0x00, 0x04, 0x00, 0x2E, 0x00, 0x00, 0x00, 0x06,
    0x00, 0x04, 0x00, 0x01, 0x00, 0x02, 0x00, 0x41,
    0x00, 0x63, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x41,
    0x00, 0x61, 0xFF, 0xFF, 0xFF, 0xC0, 0x00, 0x01,
    0x00, 0x01, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00,
    0x00, 0x02, 0x00, 0x00, 0x00, 0x04,
};
pub const CMAP12 = [_]u8{
    0x00, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA0,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0C,
    0,    0,    0,    46,   0,    0,    0,    46,
    0,    0,    0,    1,    0,    0,    0,    65,
    0,    0,    0,    66,   0,    0,    0,    1,
    0,    0,    0,    70,   0,    0,    0,    70,
    0,    0,    0,    2,    0,    0,    0,    73,
    0,    0,    0,    73,   0,    0,    0,    1,
    0,    0,    0,    75,   0,    0,    0,    75,
    0,    0,    0,    1,    0,    0,    0,    76,
    0,    0,    0,    76,   0,    0,    0,    2,
    0,    0,    0,    77,   0,    0,    0,    77,
    0,    0,    0,    1,    0,    0,    0,    79,
    0,    0,    0,    79,   0,    0,    0,    3,
    0,    0,    0,    162,  0,    0,    0,    162,
    0,    0,    0,    2,    0,    0,    0x20, 0xAC,
    0,    0,    0x20, 0xAC, 0,    0,    0,    3,
    0,    0,    0xFF, 0xFD, 0,    0,    0xFF, 0xFD,
    0,    0,    0,    0,    0,    1,    0xF6, 0x42,
    0,    1,    0xF6, 0x42, 0,    0,    0,    3,
};
pub const CMAP_HEADER = [_]u8{ 0, 0, 0, 1, 0, 3, 0, 10, 0, 0, 0, 12 };
pub const CMAP = CMAP_HEADER ++ CMAP12;
pub const CMAP_CHOICE_HEADER = [_]u8{
    0, 0, 0, 3,
    0, 3, 0, 1,
    0, 0, 0, 28,
    0, 0, 0, 4,
    0, 0, 0, 74,
    0, 3, 0, 10,
    0, 0, 0, 234,
};
pub const CMAP_CHOICES = CMAP_CHOICE_HEADER ++ CMAP4 ++ CMAP12 ++ CMAP12;
pub const CMAP_UNSUPPORTED = [_]u8{ 0, 0, 0, 1, 0, 3, 0, 0, 0, 0, 0, 12, 0, 0 };

pub const RECTANGLE_POINTS = [_]Point{
    .{ .X = 0, .Y = 0, .OnCurve = true },
    .{ .X = 4, .Y = 0, .OnCurve = true },
    .{ .X = 4, .Y = 4, .OnCurve = true },
    .{ .X = 0, .Y = 4, .OnCurve = true },
};
pub const IMPLIED_POINTS = [_]Point{
    .{ .X = 0, .Y = 0, .OnCurve = false },
    .{ .X = 4, .Y = 0, .OnCurve = false },
    .{ .X = 4, .Y = 4, .OnCurve = false },
    .{ .X = 0, .Y = 4, .OnCurve = false },
};
pub const EXPLICIT_POINTS = [_]Point{
    .{ .X = 0, .Y = 2, .OnCurve = true },
    .{ .X = 0, .Y = 0, .OnCurve = false },
    .{ .X = 2, .Y = 0, .OnCurve = true },
    .{ .X = 4, .Y = 0, .OnCurve = false },
    .{ .X = 4, .Y = 2, .OnCurve = true },
    .{ .X = 4, .Y = 4, .OnCurve = false },
    .{ .X = 2, .Y = 4, .OnCurve = true },
    .{ .X = 0, .Y = 4, .OnCurve = false },
};
