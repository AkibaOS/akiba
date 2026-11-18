//! Raster Workspace

const raster = @import("shared").raster;

const limits = raster.constants.limits;

pub const Workspace = struct {
    Cover: [limits.TILE_COLUMNS]i64,
    Area: [limits.TILE_COLUMNS]i64,
    Coverage: [limits.TILE_COLUMNS]u8,
};
