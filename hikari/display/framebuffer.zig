//! Hikari Framebuffer

const efi = @import("../efi/efi.zig");

pub const Framebuffer = struct {
    base: [*]u32,
    width: u32,
    height: u32,
    stride: u32,
    pixel_format: efi.types.graphics.PixelFormat,

    pub fn initialize(gop: *efi.protocols.GraphicsOutputProtocol) Framebuffer {
        const mode = gop.mode;
        const info = mode.info;

        return Framebuffer{
            .base = @ptrFromInt(mode.framebuffer_base),
            .width = info.horizontal_resolution,
            .height = info.vertical_resolution,
            .stride = info.pixels_per_scan_line,
            .pixel_format = info.pixel_format,
        };
    }

    pub fn put_pixel(self: *Framebuffer, x: u32, y: u32, color: Color) void {
        if (x >= self.width or y >= self.height) {
            return;
        }

        const offset = y * self.stride + x;
        self.base[offset] = color.to_pixel(self.pixel_format);
    }

    pub fn fill_rect(self: *Framebuffer, x: u32, y: u32, w: u32, h: u32, color: Color) void {
        const pixel = color.to_pixel(self.pixel_format);
        const x_end = if (x + w > self.width) self.width else x + w;
        const y_end = if (y + h > self.height) self.height else y + h;

        var py = y;
        while (py < y_end) : (py += 1) {
            var px = x;
            while (px < x_end) : (px += 1) {
                const offset = py * self.stride + px;
                self.base[offset] = pixel;
            }
        }
    }

    pub fn clear(self: *Framebuffer, color: Color) void {
        self.fill_rect(0, 0, self.width, self.height, color);
    }

    pub fn draw_horizontal_line(self: *Framebuffer, x: u32, y: u32, length: u32, color: Color) void {
        if (y >= self.height) {
            return;
        }

        const pixel = color.to_pixel(self.pixel_format);
        const x_end = if (x + length > self.width) self.width else x + length;
        const row_offset = y * self.stride;

        var px = x;
        while (px < x_end) : (px += 1) {
            self.base[row_offset + px] = pixel;
        }
    }

    pub fn draw_vertical_line(self: *Framebuffer, x: u32, y: u32, length: u32, color: Color) void {
        if (x >= self.width) {
            return;
        }

        const pixel = color.to_pixel(self.pixel_format);
        const y_end = if (y + length > self.height) self.height else y + length;

        var py = y;
        while (py < y_end) : (py += 1) {
            self.base[py * self.stride + x] = pixel;
        }
    }

    pub fn draw_rect(self: *Framebuffer, x: u32, y: u32, w: u32, h: u32, color: Color) void {
        self.draw_horizontal_line(x, y, w, color);
        self.draw_horizontal_line(x, y + h - 1, w, color);
        self.draw_vertical_line(x, y, h, color);
        self.draw_vertical_line(x + w - 1, y, h, color);
    }

    pub fn copy_rect(self: *Framebuffer, src_x: u32, src_y: u32, dst_x: u32, dst_y: u32, w: u32, h: u32) void {
        if (src_y < dst_y) {
            var row: u32 = h;
            while (row > 0) {
                row -= 1;
                self.copy_row(src_x, src_y + row, dst_x, dst_y + row, w);
            }
        } else {
            var row: u32 = 0;
            while (row < h) : (row += 1) {
                self.copy_row(src_x, src_y + row, dst_x, dst_y + row, w);
            }
        }
    }

    fn copy_row(self: *Framebuffer, src_x: u32, src_y: u32, dst_x: u32, dst_y: u32, w: u32) void {
        const src_offset = src_y * self.stride + src_x;
        const dst_offset = dst_y * self.stride + dst_x;

        if (src_x < dst_x) {
            var i: u32 = w;
            while (i > 0) {
                i -= 1;
                self.base[dst_offset + i] = self.base[src_offset + i];
            }
        } else {
            var i: u32 = 0;
            while (i < w) : (i += 1) {
                self.base[dst_offset + i] = self.base[src_offset + i];
            }
        }
    }
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn to_pixel(self: Color, format: efi.types.graphics.PixelFormat) u32 {
        return switch (format) {
            .rgb => (@as(u32, self.r) << 16) | (@as(u32, self.g) << 8) | self.b,
            .bgr => (@as(u32, self.b) << 16) | (@as(u32, self.g) << 8) | self.r,
            else => (@as(u32, self.r) << 16) | (@as(u32, self.g) << 8) | self.b,
        };
    }

    pub const black = Color.rgb(0, 0, 0);
    pub const white = Color.rgb(255, 255, 255);
    pub const red = Color.rgb(255, 0, 0);
    pub const green = Color.rgb(0, 255, 0);
    pub const blue = Color.rgb(0, 0, 255);
    pub const cyan = Color.rgb(0, 255, 255);
    pub const magenta = Color.rgb(255, 0, 255);
    pub const yellow = Color.rgb(255, 255, 0);
    pub const gray = Color.rgb(128, 128, 128);
    pub const dark_gray = Color.rgb(64, 64, 64);
    pub const light_gray = Color.rgb(192, 192, 192);
};
