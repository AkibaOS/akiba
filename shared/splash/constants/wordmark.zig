//! Wordmark Stroke Geometry

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const Glyph = splash.types.glyph.Glyph;
const Point = graphics.types.geometry.Point;
const Quad = graphics.types.geometry.Quad;

pub const GLYPH_BOX: i32 = 1000;
pub const GLYPH_GAP: i32 = 150;

const STROKES_A = [_]Quad{
    .{ .{ .X = 55, .Y = 205 }, .{ .X = 940, .Y = 120 }, .{ .X = 940, .Y = 250 }, .{ .X = 55, .Y = 335 } },
    .{ .{ .X = 690, .Y = 250 }, .{ .X = 838, .Y = 250 }, .{ .X = 250, .Y = 900 }, .{ .X = 100, .Y = 872 } },
};

const STROKES_KI = [_]Quad{
    .{ .{ .X = 105, .Y = 355 }, .{ .X = 885, .Y = 258 }, .{ .X = 885, .Y = 372 }, .{ .X = 105, .Y = 469 } },
    .{ .{ .X = 35, .Y = 585 }, .{ .X = 960, .Y = 478 }, .{ .X = 960, .Y = 596 }, .{ .X = 35, .Y = 703 } },
    .{ .{ .X = 560, .Y = 45 }, .{ .X = 700, .Y = 58 }, .{ .X = 505, .Y = 950 }, .{ .X = 365, .Y = 937 } },
};

const STROKES_BA = [_]Quad{
    .{ .{ .X = 330, .Y = 168 }, .{ .X = 452, .Y = 196 }, .{ .X = 172, .Y = 892 }, .{ .X = 58, .Y = 858 } },
    .{ .{ .X = 498, .Y = 150 }, .{ .X = 620, .Y = 172 }, .{ .X = 800, .Y = 898 }, .{ .X = 678, .Y = 912 } },
    .{ .{ .X = 792, .Y = 108 }, .{ .X = 856, .Y = 88 }, .{ .X = 900, .Y = 214 }, .{ .X = 836, .Y = 234 } },
    .{ .{ .X = 898, .Y = 82 }, .{ .X = 962, .Y = 62 }, .{ .X = 1006, .Y = 188 }, .{ .X = 942, .Y = 208 } },
};

pub const GLYPHS = [_]Glyph{
    .{ .Strokes = &STROKES_A, .Extent = 940 },
    .{ .Strokes = &STROKES_KI, .Extent = 960 },
    .{ .Strokes = &STROKES_BA, .Extent = 1006 },
};

pub const TOTAL_UNITS: i32 = 3206;
