//! Wordmark Glyph

const graphics = @import("shared").graphics;

const Quad = graphics.types.geometry.Quad;

pub const Glyph = struct {
    Strokes: []const Quad,
    Extent: i32,
};
