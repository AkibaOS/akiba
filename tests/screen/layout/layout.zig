//! Diagnostic Screen Layout

const std = @import("std");

const frame = @import("tests").screen.constants.frame;
const limits = @import("shared").raster.constants.limits;
const types = @import("tests").screen.types.geometry;

pub fn plan(width: u32, height: u32) ?types.Layout {
    const coordinate_limit: u32 = @intCast(@divTrunc(std.math.maxInt(i32), limits.ONE_PIXEL));
    const chrome_height = 2 * frame.MARGIN + frame.HEADER_HEIGHT + frame.PROGRESS_HEIGHT + frame.CONTROL_HEIGHT + 3 * frame.GAP;
    if (width < frame.MINIMUM_WIDTH or width > coordinate_limit or height > coordinate_limit or
        height < chrome_height + frame.ROW_HEIGHT + 2 * frame.INSET) return null;
    const content_width = width - 2 * frame.MARGIN;
    const log_height = height - chrome_height;
    const header_y = frame.MARGIN;
    const log_y = header_y + frame.HEADER_HEIGHT + frame.GAP;
    const progress_y = log_y + log_height + frame.GAP;
    const controls_y = progress_y + frame.PROGRESS_HEIGHT + frame.GAP;
    return .{
        .Width = width,
        .Height = height,
        .Header = region(header_y, content_width, frame.HEADER_HEIGHT),
        .Log = region(log_y, content_width, log_height),
        .Progress = region(progress_y, content_width, frame.PROGRESS_HEIGHT),
        .Controls = region(controls_y, content_width, frame.CONTROL_HEIGHT),
        .VisibleRows = (log_height - 2 * frame.INSET) / frame.ROW_HEIGHT,
    };
}

fn region(y: u32, width: u32, height: u32) types.Rect {
    return .{ .X = frame.MARGIN, .Y = y, .Width = width, .Height = height };
}
