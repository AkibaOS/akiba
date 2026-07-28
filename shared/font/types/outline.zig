//! Glyph Outline In Font Units

const font = @import("shared").font;

const limits = font.constants.limits;

pub const Point = struct {
    X: i32,
    Y: i32,
    OnCurve: bool,
};

pub const Outline = struct {
    Points: [limits.MAX_POINTS]Point,
    ContourEnds: [limits.MAX_CONTOURS]u16,
    PointCount: u16,
    ContourCount: u16,

    pub fn reset(self: *Outline) void {
        self.PointCount = 0;
        self.ContourCount = 0;
    }

    pub fn contourRange(self: *const Outline, contour: u16) struct { Start: u16, End: u16 } {
        const start = if (contour == 0) 0 else self.ContourEnds[contour - 1] + 1;
        return .{ .Start = start, .End = self.ContourEnds[contour] };
    }
};

pub const GlyphBuffer = struct {
    Shape: Outline,
    Flags: [limits.MAX_POINTS]u8,
};
