//! Firmware Viewport Scratch And Rendering State

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const screen = @import("tests").screen;
const splash = @import("shared").splash;

pub const Scratch = struct {
    Workspace: splash.types.workspace.Workspace,
    Renderer: graphics.types.renderer.TextRenderer,
};

pub const Session = struct {
    Surface: graphics.types.surface.Surface,
    Layout: screen.types.geometry.Layout,
    Face: font.types.face.font.Face,
    Scratch: *Scratch,
    Pixels: []u32,
    Progress: screen.types.model.Model,
    Frame: usize = 0,
};
