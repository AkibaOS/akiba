//! Checked Glyph Transform

const std = @import("std");

const font = @import("shared").font;

const constants = font.constants.glyf;
const FontError = font.errors.font.FontError;
const Point = font.types.outline.contour.Point;

pub const Transform = struct {
    A: i32,
    B: i32,
    C: i32,
    D: i32,
    Dx: i64,
    Dy: i64,

    pub fn identity() Transform {
        return .{ .A = constants.TRANSFORM_ONE, .B = 0, .C = 0, .D = constants.TRANSFORM_ONE, .Dx = 0, .Dy = 0 };
    }

    pub fn setOffset(self: *Transform, x: i32, y: i32, scaled: bool) FontError!void {
        const dx = if (scaled) product(self.A, x, self.C, y) else @as(i128, x) * constants.TRANSFORM_ONE;
        const dy = if (scaled) product(self.B, x, self.D, y) else @as(i128, y) * constants.TRANSFORM_ONE;
        self.Dx = try narrow(i64, dx);
        self.Dy = try narrow(i64, dy);
    }

    pub fn apply(self: Transform, x: i32, y: i32) FontError!Point {
        return .{
            .X = try narrow(i32, (product(self.A, x, self.C, y) + self.Dx) >> constants.TRANSFORM_FRACTION_BITS),
            .Y = try narrow(i32, (product(self.B, x, self.D, y) + self.Dy) >> constants.TRANSFORM_FRACTION_BITS),
            .OnCurve = false,
        };
    }

    pub fn compose(parent: Transform, child: Transform) FontError!Transform {
        const shift = constants.TRANSFORM_FRACTION_BITS;
        return .{
            .A = try narrow(i32, product(parent.A, child.A, parent.C, child.B) >> shift),
            .B = try narrow(i32, product(parent.B, child.A, parent.D, child.B) >> shift),
            .C = try narrow(i32, product(parent.A, child.C, parent.C, child.D) >> shift),
            .D = try narrow(i32, product(parent.B, child.C, parent.D, child.D) >> shift),
            .Dx = try narrow(i64, (product(parent.A, child.Dx, parent.C, child.Dy) >> shift) + parent.Dx),
            .Dy = try narrow(i64, (product(parent.B, child.Dx, parent.D, child.Dy) >> shift) + parent.Dy),
        };
    }
};

fn product(first_coefficient: i32, first_value: i64, second_coefficient: i32, second_value: i64) i128 {
    return @as(i128, first_coefficient) * first_value + @as(i128, second_coefficient) * second_value;
}

fn narrow(comptime Int: type, value: i128) FontError!Int {
    return std.math.cast(Int, value) orelse FontError.InvalidOutline;
}
