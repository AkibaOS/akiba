//! Hikari EFI Graphics Types

const base = @import("base.zig");

pub const PixelFormat = enum(u32) {
    RGB = 0,
    BGR = 1,
    Bitmask = 2,
    BltOnly = 3,
};

pub const PixelBitmask = extern struct {
    RedMask: u32,
    GreenMask: u32,
    BlueMask: u32,
    ReservedMask: u32,
};

pub const BltPixel = extern struct {
    Blue: u8,
    Green: u8,
    Red: u8,
    Reserved: u8,
};

pub const BltOperation = enum(u32) {
    VideoFill = 0,
    VideoToBuffer = 1,
    BufferToVideo = 2,
    VideoToVideo = 3,
};

pub const GraphicsOutputModeInformation = extern struct {
    Version: u32,
    HorizontalResolution: u32,
    VerticalResolution: u32,
    PixelFormat: PixelFormat,
    PixelInformation: PixelBitmask,
    PixelsPerScanLine: u32,
};

pub const GraphicsOutputProtocolMode = extern struct {
    MaxMode: u32,
    Mode: u32,
    Info: *GraphicsOutputModeInformation,
    SizeOfInfo: usize,
    FramebufferBase: base.PhysicalAddress,
    FramebufferSize: usize,
};
