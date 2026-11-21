//! Convert A Complete RGB Row To The Actual Display Format

const format = @import("shared").display.constants.format;

const Color = @import("shared").graphics.types.color.Color;
const PixelFormat = @import("shared").graphics.types.pixel.PixelFormat;

pub fn pack(mode: PixelFormat, rgb: []const u8, output: []u32) bool {
    if ((mode != .RGB and mode != .BGR) or rgb.len % format.RGB_BYTES != 0 or output.len != rgb.len / format.RGB_BYTES)
        return false;
    for (output, 0..) |*pixel, index| {
        const bytes = rgb[index * format.RGB_BYTES ..][0..format.RGB_BYTES];
        pixel.* = Color.rgb(bytes[0], bytes[1], bytes[2]).toPixel(mode);
    }
    return true;
}
