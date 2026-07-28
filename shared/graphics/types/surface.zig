//! Drawing Surface

const graphics = @import("shared").graphics;

const PixelFormat = graphics.types.pixel.PixelFormat;

pub const Surface = struct {
    Base: [*]u32,
    Width: u32,
    Height: u32,
    Stride: u32,
    Format: PixelFormat,

    pub fn initialize(base: u64, width: u32, height: u32, stride: u32, format: PixelFormat) Surface {
        return Surface{
            .Base = @ptrFromInt(base),
            .Width = width,
            .Height = height,
            .Stride = stride,
            .Format = format,
        };
    }

    pub fn contains(self: Surface, x: i32, y: i32) bool {
        return x >= 0 and y >= 0 and x < self.Width and y < self.Height;
    }

    pub fn offset(self: Surface, x: u32, y: u32) usize {
        return y * self.Stride + x;
    }
};
