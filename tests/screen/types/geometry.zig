//! Diagnostic Screen Regions

pub const Rect = struct {
    X: u32,
    Y: u32,
    Width: u32,
    Height: u32,
};

pub const Layout = struct {
    Width: u32,
    Height: u32,
    Header: Rect,
    Log: Rect,
    Progress: Rect,
    Controls: Rect,
    VisibleRows: usize,
};
