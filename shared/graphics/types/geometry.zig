//! Drawing Geometry

pub const Point = struct {
    X: i32,
    Y: i32,
};

pub const Quad = [4]Point;

pub const Stripe = struct {
    Period: i32,
    Gap: i32,
};
