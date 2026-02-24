//! Color utilities

const int = @import("../types/int.zig");

pub const RGB = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub inline fn extract(color: u32) RGB {
    return RGB{
        .r = int.u8_of(color >> 16),
        .g = int.u8_of(color >> 8),
        .b = int.u8_of(color),
    };
}

pub inline fn from_rgb(r: u8, g: u8, b: u8) u32 {
    return (int.u32_of(r) << 16) | (int.u32_of(g) << 8) | int.u32_of(b);
}

pub inline fn red(color: u32) u8 {
    return int.u8_of(color >> 16);
}

pub inline fn green(color: u32) u8 {
    return int.u8_of(color >> 8);
}

pub inline fn blue(color: u32) u8 {
    return int.u8_of(color);
}
