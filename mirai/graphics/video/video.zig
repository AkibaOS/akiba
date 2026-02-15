//! Framebuffer graphics operations

const boot = @import("../../boot/multiboot2.zig");

var fb: ?boot.FramebufferInfo = null;

pub fn init(framebuffer: boot.FramebufferInfo) void {
    fb = framebuffer;
}

pub fn clear(color: u32) void {
    if (fb) |f| {
        if (f.bpp == 32) {
            clear_32bit(f, color);
        } else if (f.bpp == 24) {
            clear_24bit(f, color);
        } else {
            clear_32bit(f, color); // Fallback
        }
    }
}

fn clear_32bit(f: boot.FramebufferInfo, color: u32) void {
    const pixels = @as([*]volatile u32, @ptrFromInt(f.addr));
    var i: usize = 0;
    const total = f.width * f.height;
    while (i < total) : (i += 1) {
        pixels[i] = color;
    }
}

fn clear_24bit(f: boot.FramebufferInfo, color: u32) void {
    const pixels = @as([*]volatile u8, @ptrFromInt(f.addr));

    const r = @as(u8, @truncate((color >> 16) & 0xFF));
    const g = @as(u8, @truncate((color >> 8) & 0xFF));
    const b = @as(u8, @truncate(color & 0xFF));

    var y: u32 = 0;
    while (y < f.height) : (y += 1) {
        var x: u32 = 0;
        while (x < f.width) : (x += 1) {
            const offset = y * f.pitch + x * 3;
            pixels[offset] = b; // Blue
            pixels[offset + 1] = g; // Green
            pixels[offset + 2] = r; // Red
        }
    }
}

pub fn put_pixel(x: u32, y: u32, color: u32) void {
    if (fb) |f| {
        if (x >= f.width or y >= f.height) return;

        if (f.bpp == 32) {
            const offset = y * (f.pitch / 4) + x;
            const pixels = @as([*]volatile u32, @ptrFromInt(f.addr));
            pixels[offset] = color;
        } else if (f.bpp == 24) {
            const offset = y * f.pitch + x * 3;
            const pixels = @as([*]volatile u8, @ptrFromInt(f.addr));

            const r = @as(u8, @truncate((color >> 16) & 0xFF));
            const g = @as(u8, @truncate((color >> 8) & 0xFF));
            const b = @as(u8, @truncate(color & 0xFF));

            pixels[offset] = b;
            pixels[offset + 1] = g;
            pixels[offset + 2] = r;
        }
    }
}
