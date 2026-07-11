//! Framebuffer State

var base: u64 = 0;
var width: u32 = 0;
var height: u32 = 0;
var stride: u32 = 0;
var initialized: bool = false;

pub fn set(framebuffer_base: u64, framebuffer_width: u32, framebuffer_height: u32, framebuffer_stride: u32) void {
    base = framebuffer_base;
    width = framebuffer_width;
    height = framebuffer_height;
    stride = framebuffer_stride;
    initialized = true;
}

pub fn get_base() u64 {
    return base;
}

pub fn get_width() u32 {
    return width;
}

pub fn get_height() u32 {
    return height;
}

pub fn get_stride() u32 {
    return stride;
}

pub fn is_initialized() bool {
    return initialized;
}
