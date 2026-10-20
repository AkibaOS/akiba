//! Glyph Transform

const font = @import("shared").font;

const constants = font.constants.glyf;

const Point = font.types.outline.Point;

pub const Transform = struct {
    A: i32,
    B: i32,
    C: i32,
    D: i32,
    Dx: i32,
    Dy: i32,

    pub fn identity() Transform {
        return Transform{
            .A = constants.TRANSFORM_ONE,
            .B = 0,
            .C = 0,
            .D = constants.TRANSFORM_ONE,
            .Dx = 0,
            .Dy = 0,
        };
    }

    pub fn apply(self: Transform, x: i32, y: i32) Point {
        return Point{
            .X = ((self.A * x + self.C * y) >> constants.TRANSFORM_FRACTION_BITS) + self.Dx,
            .Y = ((self.B * x + self.D * y) >> constants.TRANSFORM_FRACTION_BITS) + self.Dy,
            .OnCurve = false,
        };
    }

    pub fn compose(parent: Transform, child: Transform) Transform {
        const shift = constants.TRANSFORM_FRACTION_BITS;
        return Transform{
            .A = (parent.A * child.A + parent.C * child.B) >> shift,
            .B = (parent.B * child.A + parent.D * child.B) >> shift,
            .C = (parent.A * child.C + parent.C * child.D) >> shift,
            .D = (parent.B * child.C + parent.D * child.D) >> shift,
            .Dx = ((parent.A * child.Dx + parent.C * child.Dy) >> shift) + parent.Dx,
            .Dy = ((parent.B * child.Dx + parent.D * child.Dy) >> shift) + parent.Dy,
        };
    }
};
