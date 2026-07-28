//! Fixed Point Arithmetic

pub const Fixed26Dot6 = struct {
    Raw: i32,

    pub const FRACTION_BITS: u5 = 6;
    pub const ONE: i32 = 1 << FRACTION_BITS;
    pub const FRACTION_MASK: i32 = ONE - 1;

    pub const ZERO = Fixed26Dot6{ .Raw = 0 };

    pub fn fromRaw(raw: i32) Fixed26Dot6 {
        return Fixed26Dot6{ .Raw = raw };
    }

    pub fn fromInt(value: i32) Fixed26Dot6 {
        return Fixed26Dot6{ .Raw = value * ONE };
    }

    pub fn truncate(self: Fixed26Dot6) i32 {
        return self.Raw >> FRACTION_BITS;
    }

    pub fn floor(self: Fixed26Dot6) i32 {
        return @intCast(@divFloor(self.Raw, ONE));
    }

    pub fn ceiling(self: Fixed26Dot6) i32 {
        return @intCast(@divFloor(self.Raw + FRACTION_MASK, ONE));
    }

    pub fn round(self: Fixed26Dot6) i32 {
        return @intCast(@divFloor(self.Raw + ONE / 2, ONE));
    }

    pub fn fraction(self: Fixed26Dot6) i32 {
        return self.Raw - self.floor() * ONE;
    }

    pub fn add(self: Fixed26Dot6, other: Fixed26Dot6) Fixed26Dot6 {
        return Fixed26Dot6{ .Raw = self.Raw + other.Raw };
    }

    pub fn subtract(self: Fixed26Dot6, other: Fixed26Dot6) Fixed26Dot6 {
        return Fixed26Dot6{ .Raw = self.Raw - other.Raw };
    }

    pub fn multiply(self: Fixed26Dot6, other: Fixed26Dot6) Fixed26Dot6 {
        const product = @as(i64, self.Raw) * @as(i64, other.Raw);
        return Fixed26Dot6{ .Raw = @intCast(product >> FRACTION_BITS) };
    }

    pub fn divide(self: Fixed26Dot6, other: Fixed26Dot6) Fixed26Dot6 {
        if (other.Raw == 0) {
            return ZERO;
        }
        const numerator = @as(i64, self.Raw) << FRACTION_BITS;
        return Fixed26Dot6{ .Raw = @intCast(@divTrunc(numerator, @as(i64, other.Raw))) };
    }

    pub fn isLessThan(self: Fixed26Dot6, other: Fixed26Dot6) bool {
        return self.Raw < other.Raw;
    }
};

pub const Fixed16Dot16 = struct {
    Raw: i32,

    pub const FRACTION_BITS: u5 = 16;
    pub const ONE: i32 = 1 << FRACTION_BITS;

    pub fn fromRaw(raw: i32) Fixed16Dot16 {
        return Fixed16Dot16{ .Raw = raw };
    }

    pub fn fromRatio(numerator: i32, denominator: i32) Fixed16Dot16 {
        if (denominator == 0) {
            return Fixed16Dot16{ .Raw = 0 };
        }
        const scaled = @as(i64, numerator) << FRACTION_BITS;
        return Fixed16Dot16{ .Raw = @intCast(@divTrunc(scaled, @as(i64, denominator))) };
    }

    pub fn multiply(self: Fixed16Dot16, other: Fixed16Dot16) Fixed16Dot16 {
        const product = @as(i64, self.Raw) * @as(i64, other.Raw);
        return Fixed16Dot16{ .Raw = @intCast(product >> FRACTION_BITS) };
    }

    pub fn applyToUnits(self: Fixed16Dot16, units: i32) Fixed26Dot6 {
        const product = @as(i64, units) * @as(i64, self.Raw);
        return Fixed26Dot6{ .Raw = @intCast(product >> (FRACTION_BITS - Fixed26Dot6.FRACTION_BITS)) };
    }
};
