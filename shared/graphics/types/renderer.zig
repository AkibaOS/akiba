//! Text Renderer Scratch

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const raster = @import("shared").raster;

const Color = graphics.types.color.Color;
const GlyphBuffer = font.types.outline.GlyphBuffer;
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
    Workspace: Workspace,
};
