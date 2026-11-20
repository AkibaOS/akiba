//! Text Renderer Scratch

const std = @import("std");

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const raster = @import("shared").raster;

const Color = graphics.types.color.Color;
const Edge = raster.types.edge.Edge;
const GlyphBuffer = font.types.outline.contour.GlyphBuffer;
const Point = font.types.outline.contour.Point;
const Shape = raster.types.shape.Shape;
const Surface = graphics.types.surface.Surface;
const Workspace = raster.types.workspace.Workspace;

pub const BlendTarget = struct {
    Target: *Surface,
    Foreground: Color,
    Background: ?Color,
};

pub const TextRenderer = struct {
    Glyphs: GlyphBuffer,
    Shape: Shape,
    Workspace: Workspace = undefined,

    pub fn initAllocating(allocator: std.mem.Allocator) TextRenderer {
        return .{ .Glyphs = GlyphBuffer.initAllocating(allocator), .Shape = Shape.initAllocating(allocator) };
    }

    pub fn initFixed(points: []Point, contours: []usize, flags: []u8, edges: []Edge) TextRenderer {
        return .{ .Glyphs = GlyphBuffer.initFixed(points, contours, flags), .Shape = Shape.initFixed(edges) };
    }

    pub fn deinit(self: *TextRenderer) void {
        self.Shape.deinit();
        self.Glyphs.deinit();
    }
};
