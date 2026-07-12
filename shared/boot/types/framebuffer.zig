//! Boot Framebuffer Info

pub const PixelFormat = enum(u32) {
    RGB = 0,
    BGR = 1,
    Bitmask = 2,
    Unknown = 255,
};

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
};
