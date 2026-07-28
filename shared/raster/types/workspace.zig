//! Raster Workspace

const raster = @import("shared").raster;

const limits = raster.constants.limits;

pub const Workspace = struct {
    Cover: [limits.MAX_ROW_WIDTH + 2]i32,
    Area: [limits.MAX_ROW_WIDTH + 2]i32,
    Coverage: [limits.MAX_ROW_WIDTH + 2]u8,
};
