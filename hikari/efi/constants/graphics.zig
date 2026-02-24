//! Hikari EFI Graphics Constants

pub const pixel_format_rgb: u32 = 0;
pub const pixel_format_bgr: u32 = 1;
pub const pixel_format_bitmask: u32 = 2;
pub const pixel_format_blt_only: u32 = 3;

pub const blt_operation_video_fill: u32 = 0;
pub const blt_operation_video_to_buffer: u32 = 1;
pub const blt_operation_buffer_to_video: u32 = 2;
pub const blt_operation_video_to_video: u32 = 3;

pub const graphics_output_protocol_revision: u32 = 0x00010000;
