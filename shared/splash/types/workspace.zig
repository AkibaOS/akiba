//! Embedded Splash Render Storage

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const raster = @import("shared").raster;
const splash = @import("shared").splash;

const Edge = raster.types.edge.Edge;
const Point = font.types.outline.Point;
const TextRenderer = graphics.types.renderer.TextRenderer;

const limits = splash.constants.limits;

pub const Workspace = struct {
    Points: [limits.RENDER_POINTS]Point,
    Contours: [limits.RENDER_CONTOURS]usize,
    Flags: [limits.RENDER_POINTS]u8,
    Edges: [limits.RENDER_EDGES]Edge,

    pub fn bind(self: *Workspace) TextRenderer {
        return TextRenderer.initFixed(&self.Points, &self.Contours, &self.Flags, &self.Edges);
    }
};
