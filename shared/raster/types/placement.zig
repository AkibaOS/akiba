//! Raster Placement

const common = @import("common");

const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;

pub const Placement = struct {
    Scale: Fixed16Dot16,
    OriginX: i32,
    BaselineY: i32,

    pub fn deviceX(self: Placement, units: i32) i32 {
        return self.OriginX + self.Scale.applyToUnits(units).Raw;
    }

    pub fn deviceY(self: Placement, units: i32) i32 {
        return self.BaselineY - self.Scale.applyToUnits(units).Raw;
    }
};
