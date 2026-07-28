//! Color

const graphics = @import("shared").graphics;

const channels = graphics.constants.pixel;

const PixelFormat = graphics.types.pixel.PixelFormat;

pub const Color = struct {
    R: u8,
    G: u8,
    B: u8,

    pub fn rgb(red: u8, green: u8, blue: u8) Color {
        return Color{ .R = red, .G = green, .B = blue };
    }

    pub fn toPixel(self: Color, format: PixelFormat) u32 {
        return switch (format) {
            .RGB => (@as(u32, self.B) << channels.SHIFT_HIGH) |
                (@as(u32, self.G) << channels.SHIFT_MIDDLE) |
                (@as(u32, self.R) << channels.SHIFT_LOW),
            else => (@as(u32, self.R) << channels.SHIFT_HIGH) |
                (@as(u32, self.G) << channels.SHIFT_MIDDLE) |
                (@as(u32, self.B) << channels.SHIFT_LOW),
        };
    }

    pub fn blend(self: Color, other: Color, numerator: u32, denominator: u32) Color {
        return Color{
            .R = mix(self.R, other.R, numerator, denominator),
            .G = mix(self.G, other.G, numerator, denominator),
            .B = mix(self.B, other.B, numerator, denominator),
        };
    }
};

pub const BLACK = Color.rgb(0x00, 0x00, 0x00);
pub const WHITE = Color.rgb(0xFF, 0xFF, 0xFF);

fn mix(from: u8, to: u8, numerator: u32, denominator: u32) u8 {
    const start: u32 = from;
    const end: u32 = to;
    if (end >= start) {
        return @truncate(start + (end - start) * numerator / denominator);
    }
    return @truncate(start - (start - end) * numerator / denominator);
}
