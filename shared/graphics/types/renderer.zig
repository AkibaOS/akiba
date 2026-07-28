//! Text Renderer Scratch

const font = @import("shared").font;
const raster = @import("shared").raster;

const GlyphBuffer = font.types.outline.GlyphBuffer;
const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

pub const TextRenderer = struct {
    Glyphs: GlyphBuffer,
    Shape: Shape,
    Workspace: Workspace,
};
