//! Diagnostic Screen Text Resources

const font = @import("shared").font;
const graphics = @import("shared").graphics;

pub const Text = struct {
    Face: *const font.types.face.font.Face,
    Renderer: *graphics.types.renderer.TextRenderer,
};
