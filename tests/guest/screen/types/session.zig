//! Standard Guest Screen Ownership

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const screen = @import("tests").screen;

pub const Rollback = struct {
    Timer: ?u16,
    Clock: screen.types.clock.Clock,
    Percent: usize = 0,
    FilledSlots: usize = 0,
};

pub const Session = struct {
    Surface: graphics.types.surface.Surface,
    Layout: screen.types.geometry.Layout,
    Face: font.types.face.font.Face,
    Physical: u64,
    Pages: u64,
    Pixels: []u32,
    Rows: []screen.types.model.Row,
    Progress: screen.types.model.Model,
    Started: u64 = 0,
    LastFrame: usize = 0,
    Rendering: bool = false,
    RollbackView: ?Rollback = null,
};
