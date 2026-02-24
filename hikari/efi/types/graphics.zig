//! Hikari EFI Graphics Types

const base = @import("base.zig");

pub const PixelFormat = enum(u32) {
    rgb = 0,
    bgr = 1,
    bitmask = 2,
    blt_only = 3,
};

pub const PixelBitmask = extern struct {
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,
    reserved_mask: u32,
};

pub const BltPixel = extern struct {
    blue: u8,
    green: u8,
    red: u8,
    reserved: u8,
};

pub const BltOperation = enum(u32) {
    video_fill = 0,
    video_to_buffer = 1,
    buffer_to_video = 2,
    video_to_video = 3,
};

pub const GraphicsOutputModeInformation = extern struct {
    version: u32,
    horizontal_resolution: u32,
    vertical_resolution: u32,
    pixel_format: PixelFormat,
    pixel_information: PixelBitmask,
    pixels_per_scan_line: u32,
};

pub const GraphicsOutputProtocolMode = extern struct {
    max_mode: u32,
    mode: u32,
    info: *GraphicsOutputModeInformation,
    size_of_info: usize,
    framebuffer_base: base.PhysicalAddress,
    framebuffer_size: usize,
};
