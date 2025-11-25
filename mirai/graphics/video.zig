//! Framebuffer graphics operations

const boot = @import("../boot/multiboot2.zig");

var fb: ?boot.FramebufferInfo = null;

pub fn init(framebuffer: boot.FramebufferInfo) void {
    fb = framebuffer;
}

pub fn clear(color: u32) void {
    if (fb) |f| {
        const pixels = @as([*]volatile u32, @ptrFromInt(f.addr));
        var i: usize = 0;
        const total = f.width * f.height;
        while (i < total) : (i += 1) {
            pixels[i] = color;
        }
    }
}

pub fn put_pixel(x: u32, y: u32, color: u32) void {
    if (fb) |f| {
        if (x >= f.width or y >= f.height) return;
        const offset = y * (f.pitch / 4) + x;
        const pixels = @as([*]volatile u32, @ptrFromInt(f.addr));
        pixels[offset] = color;
    }
}
