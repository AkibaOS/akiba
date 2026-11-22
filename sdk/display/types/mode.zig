//! Display Geometry Without Framebuffer Addresses

const PixelFormat = @import("sdk").display.types.pixel.PixelFormat;

pub const Mode = extern struct {
    Width: u32,
    Height: u32,
    Stride: u32,
    Format: PixelFormat,

    pub fn isValid(self: Mode) bool {
        return self.Width != 0 and self.Height != 0 and self.Stride >= self.Width and
            (self.Format == .RGB or self.Format == .BGR);
    }
};
