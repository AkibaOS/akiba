//! Verified EFI Diagnostic Footer Workspace

const efi = @import("hikari").efi;
const font = @import("shared").font;
const graphics = @import("shared").graphics;
const screen = @import("tests").screen;

pub const View = struct {
    Pool: efi.types.buffer.claims.PoolClaim = .{},
    Target: graphics.types.surface.Surface = undefined,
    Layout: screen.types.geometry.Layout = undefined,
    Face: font.types.face.font.Face = undefined,
    Renderer: graphics.types.renderer.TextRenderer = undefined,
    Pixels: []u32 = &.{},
};
