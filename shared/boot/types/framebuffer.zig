//! Boot Framebuffer Info

const graphics = @import("shared").graphics;

pub const PixelFormat = graphics.types.pixel.PixelFormat;

pub const FramebufferInfo = extern struct {
    Base: u64,
    Size: u64,
    Width: u32,
    Height: u32,
    Stride: u32,
    PixelFormat: PixelFormat,
    RedMaskSize: u8,
    RedMaskShift: u8,
    GreenMaskSize: u8,
    GreenMaskShift: u8,
    BlueMaskSize: u8,
    BlueMaskShift: u8,
    Reserved: [2]u8,

    pub fn isValid(self: FramebufferInfo) bool {
        if (self.Base == 0 or self.Base % @alignOf(u32) != 0 or self.Size == 0 or
            self.Size > ~@as(u64, 0) - self.Base or self.Width == 0 or self.Height == 0 or
            self.Stride < self.Width or (self.PixelFormat != .RGB and self.PixelFormat != .BGR)) return false;
        const row_bytes = @as(u64, self.Stride) * @sizeOf(u32);
        return self.Height <= self.Size / row_bytes;
    }
};
