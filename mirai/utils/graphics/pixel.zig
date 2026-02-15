//! Pixel and framebuffer utilities

const boot = @import("../../boot/multiboot2.zig");
const color = @import("color.zig");
const gfx = @import("../../common/constants/graphics.zig");

pub inline fn ptr_32(addr: u64) [*]volatile u32 {
    return @as([*]volatile u32, @ptrFromInt(addr));
}

pub inline fn ptr_8(addr: u64) [*]volatile u8 {
    return @as([*]volatile u8, @ptrFromInt(addr));
}

pub inline fn offset_32(fb: boot.FramebufferInfo, x: u32, y: u32) usize {
    return y * (fb.pitch / gfx.BYTES_PER_PIXEL_32) + x;
}

pub inline fn offset_24(fb: boot.FramebufferInfo, x: u32, y: u32) usize {
    return y * fb.pitch + x * gfx.BYTES_PER_PIXEL_24;
}

pub inline fn pixels_per_row(fb: boot.FramebufferInfo) u32 {
    return fb.pitch / gfx.BYTES_PER_PIXEL_32;
}

pub fn put(fb: boot.FramebufferInfo, x: u32, y: u32, c: u32) void {
    if (x >= fb.width or y >= fb.height) return;

    if (fb.bpp == gfx.BPP_32) {
        put_32(fb, x, y, c);
    } else if (fb.bpp == gfx.BPP_24) {
        put_24(fb, x, y, c);
    }
}

pub fn put_32(fb: boot.FramebufferInfo, x: u32, y: u32, c: u32) void {
    const pixels = ptr_32(fb.addr);
    pixels[offset_32(fb, x, y)] = c;
}

pub fn put_24(fb: boot.FramebufferInfo, x: u32, y: u32, c: u32) void {
    const pixels = ptr_8(fb.addr);
    const off = offset_24(fb, x, y);
    const rgb = color.extract(c);
    pixels[off] = rgb.b;
    pixels[off + 1] = rgb.g;
    pixels[off + 2] = rgb.r;
}

pub fn fill(fb: boot.FramebufferInfo, c: u32) void {
    if (fb.bpp == gfx.BPP_32) {
        fill_32(fb, c);
    } else if (fb.bpp == gfx.BPP_24) {
        fill_24(fb, c);
    }
}

pub fn fill_32(fb: boot.FramebufferInfo, c: u32) void {
    const pixels = ptr_32(fb.addr);
    const total = fb.width * fb.height;
    var i: usize = 0;
    while (i < total) : (i += 1) {
        pixels[i] = c;
    }
}

pub fn fill_24(fb: boot.FramebufferInfo, c: u32) void {
    const pixels = ptr_8(fb.addr);
    const rgb = color.extract(c);

    var y: u32 = 0;
    while (y < fb.height) : (y += 1) {
        var x: u32 = 0;
        while (x < fb.width) : (x += 1) {
            const off = offset_24(fb, x, y);
            pixels[off] = rgb.b;
            pixels[off + 1] = rgb.g;
            pixels[off + 2] = rgb.r;
        }
    }
}

pub fn fill_rect(fb: boot.FramebufferInfo, x: u32, y: u32, w: u32, h: u32, c: u32) void {
    if (fb.bpp == gfx.BPP_32) {
        fill_rect_32(fb, x, y, w, h, c);
    } else if (fb.bpp == gfx.BPP_24) {
        fill_rect_24(fb, x, y, w, h, c);
    }
}

pub fn fill_rect_32(fb: boot.FramebufferInfo, x: u32, y: u32, w: u32, h: u32, c: u32) void {
    const pixels = ptr_32(fb.addr);

    var row: u32 = 0;
    while (row < h) : (row += 1) {
        var col: u32 = 0;
        while (col < w) : (col += 1) {
            const px = x + col;
            const py = y + row;
            if (px < fb.width and py < fb.height) {
                pixels[offset_32(fb, px, py)] = c;
            }
        }
    }
}

pub fn fill_rect_24(fb: boot.FramebufferInfo, x: u32, y: u32, w: u32, h: u32, c: u32) void {
    const pixels = ptr_8(fb.addr);
    const rgb = color.extract(c);

    var row: u32 = 0;
    while (row < h) : (row += 1) {
        var col: u32 = 0;
        while (col < w) : (col += 1) {
            const px = x + col;
            const py = y + row;
            if (px < fb.width and py < fb.height) {
                const off = offset_24(fb, px, py);
                pixels[off] = rgb.b;
                pixels[off + 1] = rgb.g;
                pixels[off + 2] = rgb.r;
            }
        }
    }
}

pub fn copy_row(fb: boot.FramebufferInfo, dst_y: u32, src_y: u32) void {
    if (fb.bpp == gfx.BPP_32) {
        copy_row_32(fb, dst_y, src_y);
    } else if (fb.bpp == gfx.BPP_24) {
        copy_row_24(fb, dst_y, src_y);
    }
}

pub fn copy_row_32(fb: boot.FramebufferInfo, dst_y: u32, src_y: u32) void {
    const pixels = ptr_32(fb.addr);
    const ppr = pixels_per_row(fb);

    var x: u32 = 0;
    while (x < fb.width) : (x += 1) {
        pixels[dst_y * ppr + x] = pixels[src_y * ppr + x];
    }
}

pub fn copy_row_24(fb: boot.FramebufferInfo, dst_y: u32, src_y: u32) void {
    const pixels = ptr_8(fb.addr);

    var x: u32 = 0;
    while (x < fb.width) : (x += 1) {
        const src_off = offset_24(fb, x, src_y);
        const dst_off = offset_24(fb, x, dst_y);
        pixels[dst_off] = pixels[src_off];
        pixels[dst_off + 1] = pixels[src_off + 1];
        pixels[dst_off + 2] = pixels[src_off + 2];
    }
}

pub fn clear_row(fb: boot.FramebufferInfo, y: u32, c: u32) void {
    if (fb.bpp == gfx.BPP_32) {
        clear_row_32(fb, y, c);
    } else if (fb.bpp == gfx.BPP_24) {
        clear_row_24(fb, y, c);
    }
}

pub fn clear_row_32(fb: boot.FramebufferInfo, y: u32, c: u32) void {
    const pixels = ptr_32(fb.addr);
    const ppr = pixels_per_row(fb);

    var x: u32 = 0;
    while (x < fb.width) : (x += 1) {
        pixels[y * ppr + x] = c;
    }
}

pub fn clear_row_24(fb: boot.FramebufferInfo, y: u32, c: u32) void {
    const pixels = ptr_8(fb.addr);
    const rgb = color.extract(c);

    var x: u32 = 0;
    while (x < fb.width) : (x += 1) {
        const off = offset_24(fb, x, y);
        pixels[off] = rgb.b;
        pixels[off + 1] = rgb.g;
        pixels[off + 2] = rgb.r;
    }
}

pub fn line_width(fb: boot.FramebufferInfo) u32 {
    if (fb.bpp == gfx.BPP_32) {
        return fb.pitch / gfx.BYTES_PER_PIXEL_32;
    } else if (fb.bpp == gfx.BPP_24) {
        return fb.pitch / gfx.BYTES_PER_PIXEL_24;
    }
    return fb.width;
}
