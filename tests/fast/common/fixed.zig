//! Fixed Point Regression Checks

const std = @import("std");

const constants = @import("tests").fast.constants.utils.vectors;
const fixed = @import("common").datatypes.fixed.types;

pub fn fixed26Construction() !void {
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.ZERO.Raw);
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.fromInt(0).Raw);
    try std.testing.expectEqual(@as(i32, 64), fixed.subpixel.Fixed26Dot6.fromInt(1).Raw);
    try std.testing.expectEqual(@as(i32, -64), fixed.subpixel.Fixed26Dot6.fromInt(-1).Raw);
    try std.testing.expectEqual(@as(i32, 2147483584), fixed.subpixel.Fixed26Dot6.fromInt(33554431).Raw);
    try std.testing.expectEqual(@as(i32, -2147483648), fixed.subpixel.Fixed26Dot6.fromInt(-33554432).Raw);
    try std.testing.expectEqual(@as(i32, 2147483647), fixed.subpixel.Fixed26Dot6.fromRaw(2147483647).Raw);
    try std.testing.expectEqual(@as(i32, -2147483648), fixed.subpixel.Fixed26Dot6.fromRaw(-2147483648).Raw);
}

pub fn fixed26SignedRounding() !void {
    for (constants.FIXED26_ROUNDING_CASES) |case| {
        const value = fixed.subpixel.Fixed26Dot6.fromRaw(case.Raw);
        try std.testing.expectEqual(case.Floor, value.floor());
        try std.testing.expectEqual(case.Ceiling, value.ceiling());
        try std.testing.expectEqual(case.Round, value.round());
        try std.testing.expectEqual(case.Fraction, value.fraction());
    }
}

pub fn fixed26Truncation() !void {
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.fromRaw(0).truncate());
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.fromRaw(63).truncate());
    try std.testing.expectEqual(@as(i32, 1), fixed.subpixel.Fixed26Dot6.fromRaw(64).truncate());
    try std.testing.expectEqual(@as(i32, 1), fixed.subpixel.Fixed26Dot6.fromRaw(127).truncate());
    try std.testing.expectEqual(@as(i32, -1), fixed.subpixel.Fixed26Dot6.fromRaw(-64).truncate());
    try std.testing.expectEqual(@as(i32, -33554432), fixed.subpixel.Fixed26Dot6.fromRaw(-2147483648).truncate());
}

pub fn fixed26AdditionAndSubtraction() !void {
    const positive = fixed.subpixel.Fixed26Dot6.fromRaw(96);
    const negative = fixed.subpixel.Fixed26Dot6.fromRaw(-144);

    try std.testing.expectEqual(@as(i32, -48), positive.add(negative).Raw);
    try std.testing.expectEqual(@as(i32, 240), positive.subtract(negative).Raw);
    try std.testing.expectEqual(@as(i32, -240), negative.subtract(positive).Raw);
    try std.testing.expectEqual(@as(i32, 0), positive.subtract(positive).Raw);
    try std.testing.expectEqual(@as(i32, 96), positive.add(fixed.subpixel.Fixed26Dot6.ZERO).Raw);
    try std.testing.expectEqual(@as(i32, 64), fixed.subpixel.Fixed26Dot6.fromRaw(63).add(fixed.subpixel.Fixed26Dot6.fromRaw(1)).Raw);
}

pub fn fixed26Multiplication() !void {
    const positive = fixed.subpixel.Fixed26Dot6.fromRaw(96);
    const negative = fixed.subpixel.Fixed26Dot6.fromRaw(-96);
    const factor = fixed.subpixel.Fixed26Dot6.fromRaw(80);

    try std.testing.expectEqual(@as(i32, 120), positive.multiply(factor).Raw);
    try std.testing.expectEqual(@as(i32, -120), negative.multiply(factor).Raw);
    try std.testing.expectEqual(@as(i32, 144), negative.multiply(negative).Raw);
    try std.testing.expectEqual(@as(i32, 0), positive.multiply(fixed.subpixel.Fixed26Dot6.ZERO).Raw);
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.fromRaw(1).multiply(fixed.subpixel.Fixed26Dot6.fromRaw(32)).Raw);
    try std.testing.expectEqual(@as(i32, -1), fixed.subpixel.Fixed26Dot6.fromRaw(-1).multiply(fixed.subpixel.Fixed26Dot6.fromRaw(32)).Raw);
    try std.testing.expectEqual(@as(i32, 1073741824), fixed.subpixel.Fixed26Dot6.fromRaw(1073741824).multiply(fixed.subpixel.Fixed26Dot6.fromRaw(64)).Raw);
}

pub fn fixed26Division() !void {
    const numerator = fixed.subpixel.Fixed26Dot6.fromRaw(64);
    const denominator = fixed.subpixel.Fixed26Dot6.fromRaw(192);

    try std.testing.expectEqual(@as(i32, 21), numerator.divide(denominator).Raw);
    try std.testing.expectEqual(@as(i32, -21), fixed.subpixel.Fixed26Dot6.fromRaw(-64).divide(denominator).Raw);
    try std.testing.expectEqual(@as(i32, -21), numerator.divide(fixed.subpixel.Fixed26Dot6.fromRaw(-192)).Raw);
    try std.testing.expectEqual(@as(i32, 21), fixed.subpixel.Fixed26Dot6.fromRaw(-64).divide(fixed.subpixel.Fixed26Dot6.fromRaw(-192)).Raw);
    try std.testing.expectEqual(@as(i32, 48), fixed.subpixel.Fixed26Dot6.fromRaw(96).divide(fixed.subpixel.Fixed26Dot6.fromRaw(128)).Raw);
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.fromRaw(-1).divide(denominator).Raw);
    try std.testing.expectEqual(@as(i32, 1073741824), fixed.subpixel.Fixed26Dot6.fromRaw(1073741824).divide(numerator).Raw);
}

pub fn fixed26ZeroDivision() !void {
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.fromRaw(96).divide(fixed.subpixel.Fixed26Dot6.ZERO).Raw);
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.fromRaw(-96).divide(fixed.subpixel.Fixed26Dot6.ZERO).Raw);
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.ZERO.divide(fixed.subpixel.Fixed26Dot6.ZERO).Raw);
    try std.testing.expectEqual(@as(i32, 0), fixed.subpixel.Fixed26Dot6.ZERO.divide(fixed.subpixel.Fixed26Dot6.fromRaw(96)).Raw);
}

pub fn fixed26Ordering() !void {
    const minimum = fixed.subpixel.Fixed26Dot6.fromRaw(-2147483648);
    const negative = fixed.subpixel.Fixed26Dot6.fromRaw(-1);
    const positive = fixed.subpixel.Fixed26Dot6.fromRaw(1);
    const maximum = fixed.subpixel.Fixed26Dot6.fromRaw(2147483647);

    try std.testing.expect(minimum.isLessThan(negative));
    try std.testing.expect(negative.isLessThan(fixed.subpixel.Fixed26Dot6.ZERO));
    try std.testing.expect(fixed.subpixel.Fixed26Dot6.ZERO.isLessThan(positive));
    try std.testing.expect(positive.isLessThan(maximum));
    try std.testing.expect(!maximum.isLessThan(minimum));
    try std.testing.expect(!negative.isLessThan(negative));
}

pub fn fixed16SignedRatios() !void {
    for (constants.FIXED16_RATIO_CASES) |case| {
        try std.testing.expectEqual(case.Raw, (try fixed.ratio.Fixed16Dot16.fromRatio(case.Numerator, case.Denominator)).Raw);
    }
}

pub fn fixed16NegativeDenominators() !void {
    for (constants.FIXED16_NEGATIVE_RATIO_CASES) |case| {
        try std.testing.expectEqual(case.Raw, (try fixed.ratio.Fixed16Dot16.fromRatio(case.Numerator, case.Denominator)).Raw);
    }
}

pub fn fixed16ZeroDenominator() !void {
    try std.testing.expectEqual(@as(i32, 0), (try fixed.ratio.Fixed16Dot16.fromRatio(0, 0)).Raw);
    try std.testing.expectEqual(@as(i32, 0), (try fixed.ratio.Fixed16Dot16.fromRatio(1, 0)).Raw);
    try std.testing.expectEqual(@as(i32, 0), (try fixed.ratio.Fixed16Dot16.fromRatio(-1, 0)).Raw);
}

pub fn fixed16Multiplication() !void {
    const positive = fixed.ratio.Fixed16Dot16.fromRaw(98304);
    const negative = fixed.ratio.Fixed16Dot16.fromRaw(-98304);
    const factor = fixed.ratio.Fixed16Dot16.fromRaw(81920);

    try std.testing.expectEqual(@as(i32, 122880), positive.multiply(factor).Raw);
    try std.testing.expectEqual(@as(i32, -122880), negative.multiply(factor).Raw);
    try std.testing.expectEqual(@as(i32, 147456), negative.multiply(negative).Raw);
    try std.testing.expectEqual(@as(i32, 0), positive.multiply(fixed.ratio.Fixed16Dot16.fromRaw(0)).Raw);
    try std.testing.expectEqual(@as(i32, 0), fixed.ratio.Fixed16Dot16.fromRaw(1).multiply(fixed.ratio.Fixed16Dot16.fromRaw(32768)).Raw);
    try std.testing.expectEqual(@as(i32, -1), fixed.ratio.Fixed16Dot16.fromRaw(-1).multiply(fixed.ratio.Fixed16Dot16.fromRaw(32768)).Raw);
    try std.testing.expectEqual(@as(i32, 1073741824), fixed.ratio.Fixed16Dot16.fromRaw(1073741824).multiply(fixed.ratio.Fixed16Dot16.fromRaw(65536)).Raw);
}

pub fn fixed16UnitScaling() !void {
    const scale = try fixed.ratio.Fixed16Dot16.fromRatio(3, 2);
    const half = fixed.ratio.Fixed16Dot16.fromRaw(512);
    const below_half = fixed.ratio.Fixed16Dot16.fromRaw(511);
    const negative_half = fixed.ratio.Fixed16Dot16.fromRaw(-512);
    const identity = fixed.ratio.Fixed16Dot16.fromRaw(65536);

    try std.testing.expectEqual(@as(i32, 480), (try scale.applyToUnits(5)).Raw);
    try std.testing.expectEqual(@as(i32, -480), (try scale.applyToUnits(-5)).Raw);
    try std.testing.expectEqual(@as(i32, 0), (try scale.applyToUnits(0)).Raw);
    try std.testing.expectEqual(@as(i32, 1), (try half.applyToUnits(1)).Raw);
    try std.testing.expectEqual(@as(i32, -1), (try half.applyToUnits(-1)).Raw);
    try std.testing.expectEqual(@as(i32, 0), (try below_half.applyToUnits(1)).Raw);
    try std.testing.expectEqual(@as(i32, 0), (try below_half.applyToUnits(-1)).Raw);
    try std.testing.expectEqual(@as(i32, -1), (try negative_half.applyToUnits(1)).Raw);
    try std.testing.expectEqual(@as(i32, 1), (try negative_half.applyToUnits(-1)).Raw);
    try std.testing.expectEqual(@as(i32, 2147483584), (try identity.applyToUnits(33554431)).Raw);
    try std.testing.expectEqual(@as(i32, -2147483648), (try identity.applyToUnits(-33554432)).Raw);
    try std.testing.expectError(error.Overflow, identity.applyToUnits(33554432));
    try std.testing.expectError(error.Overflow, fixed.ratio.Fixed16Dot16.fromRatio(std.math.maxInt(i32), 1));
}
