//! Framebuffer video operations

const boot = @import("../../boot/multiboot/multiboot.zig");
const pixel = @import("../../utils/graphics/pixel.zig");

var fb: ?boot.FramebufferInfo = null;

pub fn init(framebuffer: boot.FramebufferInfo) void {
    fb = framebuffer;
}

pub fn clear(c: u32) void {
    if (fb) |f| {
        pixel.fill(f, c);
    }
}

pub fn put_pixel(x: u32, y: u32, c: u32) void {
    if (fb) |f| {
        pixel.put(f, x, y, c);
    }
}

pub fn fill_rect(x: u32, y: u32, w: u32, h: u32, c: u32) void {
    if (fb) |f| {
        pixel.fill_rect(f, x, y, w, h, c);
    }
}

pub fn get_width() u32 {
    if (fb) |f| return f.width;
    return 0;
}

pub fn get_height() u32 {
    if (fb) |f| return f.height;
    return 0;
}

pub fn get_framebuffer() ?boot.FramebufferInfo {
    return fb;
}
