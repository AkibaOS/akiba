//! Signed Fixed Point Scale Ratios

const std = @import("std");

const Fixed26Dot6 = @import("common").datatypes.fixed.types.subpixel.Fixed26Dot6;

pub const Fixed16Dot16 = struct {
    Raw: i32,

    pub const FRACTION_BITS: u5 = 16;
    pub const ONE: i32 = 1 << FRACTION_BITS;

    pub fn fromRaw(raw: i32) Fixed16Dot16 {
        return Fixed16Dot16{ .Raw = raw };
    }

    pub fn fromRatio(numerator: i32, denominator: i32) error{Overflow}!Fixed16Dot16 {
        if (denominator == 0) {
            return Fixed16Dot16{ .Raw = 0 };
        }
        const scaled = @as(i64, numerator) << FRACTION_BITS;
        const rounded = roundedDivide(scaled, denominator);
        return Fixed16Dot16{ .Raw = std.math.cast(i32, rounded) orelse return error.Overflow };
    }

    pub fn multiply(self: Fixed16Dot16, other: Fixed16Dot16) Fixed16Dot16 {
        const product = @as(i64, self.Raw) * @as(i64, other.Raw);
        return Fixed16Dot16{ .Raw = @intCast(product >> FRACTION_BITS) };
    }

    pub fn applyToUnits(self: Fixed16Dot16, units: i32) error{Overflow}!Fixed26Dot6 {
        return Fixed26Dot6{ .Raw = std.math.cast(i32, self.applyToUnitsRawWide(units)) orelse return error.Overflow };
    }

    pub fn applyToUnitsRawWide(self: Fixed16Dot16, units: i32) i64 {
        const product = @as(i64, units) * self.Raw;
        const divisor = @as(i64, 1) << (FRACTION_BITS - Fixed26Dot6.FRACTION_BITS);
        return roundedDivide(product, divisor);
    }
};

fn roundedDivide(numerator: i64, denominator: i64) i64 {
    const divisor = if (denominator < 0) -denominator else denominator;
    const dividend = if (denominator < 0) -numerator else numerator;
    const half = @divTrunc(divisor, 2);
    const biased = if (dividend >= 0) dividend + half else dividend - half;
    return @divTrunc(biased, divisor);
}
