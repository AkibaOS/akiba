//! Checked Glyph Transform

const std = @import("std");

const font = @import("shared").font;

const constants = font.constants.glyf;
const FontError = font.errors.font.FontError;
const Point = font.types.outline.Point;

pub const Transform = struct {
    A: i32,
    B: i32,
    C: i32,
    D: i32,
    Dx: i32,
    Dy: i32,

    pub fn identity() Transform {
        return .{ .A = constants.TRANSFORM_ONE, .B = 0, .C = 0, .D = constants.TRANSFORM_ONE, .Dx = 0, .Dy = 0 };
    }

    pub fn apply(self: Transform, x: i32, y: i32) FontError!Point {
        return .{
            .X = try component(self.A, x, self.C, y, self.Dx),
            .Y = try component(self.B, x, self.D, y, self.Dy),
            .OnCurve = false,
        };
    }

    pub fn compose(parent: Transform, child: Transform) FontError!Transform {
        return .{
            .A = try component(parent.A, child.A, parent.C, child.B, 0),
            .B = try component(parent.B, child.A, parent.D, child.B, 0),
            .C = try component(parent.A, child.C, parent.C, child.D, 0),
            .D = try component(parent.B, child.C, parent.D, child.D, 0),
            .Dx = try component(parent.A, child.Dx, parent.C, child.Dy, parent.Dx),
            .Dy = try component(parent.B, child.Dx, parent.D, child.Dy, parent.Dy),
        };
    }
};

fn component(first_coefficient: i32, first_value: i32, second_coefficient: i32, second_value: i32, offset: i32) FontError!i32 {
    const sum = @as(i128, first_coefficient) * first_value + @as(i128, second_coefficient) * second_value;
    return std.math.cast(i32, (sum >> constants.TRANSFORM_FRACTION_BITS) + offset) orelse FontError.InvalidOutline;
}
