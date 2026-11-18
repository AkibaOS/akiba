//! Raster Placement

const std = @import("std");

const common = @import("common");
const raster = @import("shared").raster;

const CoordinateError = raster.errors.raster.CoordinateError;
const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;

const limits = raster.constants.limits;

pub const Placement = struct {
    Scale: Fixed16Dot16,
    OriginX: i32,
    BaselineY: i32,

    pub fn pixelCoordinate(pixels: i32) CoordinateError!i32 {
        return std.math.cast(i32, @as(i64, pixels) * limits.ONE_PIXEL) orelse CoordinateError.CoordinateOutOfRange;
    }

    pub fn deviceX(self: Placement, units: i32) CoordinateError!i32 {
        const coordinate = @as(i64, self.OriginX) + self.Scale.applyToUnitsRawWide(units);
        return std.math.cast(i32, coordinate) orelse CoordinateError.CoordinateOutOfRange;
    }

    pub fn deviceY(self: Placement, units: i32) CoordinateError!i32 {
        const coordinate = @as(i64, self.BaselineY) - self.Scale.applyToUnitsRawWide(units);
        return std.math.cast(i32, coordinate) orelse CoordinateError.CoordinateOutOfRange;
    }
};
