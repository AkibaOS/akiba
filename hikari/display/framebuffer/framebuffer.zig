//! Hikari Framebuffer

const efi = @import("hikari").efi;

pub const Framebuffer = struct {
    Base: [*]u32,
    Width: u32,
    Height: u32,
    Stride: u32,
    PixelFormat: efi.types.graphics.PixelFormat,

    pub fn initialize(gop: *efi.protocols.graphics.GraphicsOutputProtocol) Framebuffer {
        const mode = gop.Mode;
        const info = mode.Info;

        return Framebuffer{
            .Base = @ptrFromInt(mode.FramebufferBase),
            .Width = info.HorizontalResolution,
            .Height = info.VerticalResolution,
            .Stride = info.PixelsPerScanLine,
            .PixelFormat = info.PixelFormat,
        };
    }

    pub fn putPixel(self: *Framebuffer, x: u32, y: u32, color: Color) void {
        if (x >= self.Width or y >= self.Height) {
            return;
        }

        const offset = y * self.Stride + x;
        self.Base[offset] = color.toPixel(self.PixelFormat);
    }

    pub fn fillRect(self: *Framebuffer, x: u32, y: u32, width: u32, height: u32, color: Color) void {
        const pixel = color.toPixel(self.PixelFormat);
        const x_end = if (x + width > self.Width) self.Width else x + width;
        const y_end = if (y + height > self.Height) self.Height else y + height;

        var row = y;
        while (row < y_end) : (row += 1) {
            var column = x;
            while (column < x_end) : (column += 1) {
                const offset = row * self.Stride + column;
                self.Base[offset] = pixel;
            }
        }
    }

    pub fn clear(self: *Framebuffer, color: Color) void {
        self.fillRect(0, 0, self.Width, self.Height, color);
    }

    pub fn drawHorizontalLine(self: *Framebuffer, x: u32, y: u32, length: u32, color: Color) void {
        if (y >= self.Height) {
            return;
        }

        const pixel = color.toPixel(self.PixelFormat);
        const x_end = if (x + length > self.Width) self.Width else x + length;
        const row_offset = y * self.Stride;

        var column = x;
        while (column < x_end) : (column += 1) {
            self.Base[row_offset + column] = pixel;
        }
    }

    pub fn drawVerticalLine(self: *Framebuffer, x: u32, y: u32, length: u32, color: Color) void {
        if (x >= self.Width) {
            return;
        }

        const pixel = color.toPixel(self.PixelFormat);
        const y_end = if (y + length > self.Height) self.Height else y + length;

        var row = y;
        while (row < y_end) : (row += 1) {
            self.Base[row * self.Stride + x] = pixel;
        }
    }

    pub fn drawRect(self: *Framebuffer, x: u32, y: u32, width: u32, height: u32, color: Color) void {
        self.drawHorizontalLine(x, y, width, color);
        self.drawHorizontalLine(x, y + height - 1, width, color);
        self.drawVerticalLine(x, y, height, color);
        self.drawVerticalLine(x + width - 1, y, height, color);
    }

    pub fn copyRect(self: *Framebuffer, source_x: u32, source_y: u32, destination_x: u32, destination_y: u32, width: u32, height: u32) void {
        if (source_y < destination_y) {
            var row: u32 = height;
            while (row > 0) {
                row -= 1;
                self.copyRow(source_x, source_y + row, destination_x, destination_y + row, width);
            }
        } else {
            var row: u32 = 0;
            while (row < height) : (row += 1) {
                self.copyRow(source_x, source_y + row, destination_x, destination_y + row, width);
            }
        }
    }

    fn copyRow(self: *Framebuffer, source_x: u32, source_y: u32, destination_x: u32, destination_y: u32, width: u32) void {
        const source_offset = source_y * self.Stride + source_x;
        const destination_offset = destination_y * self.Stride + destination_x;

        if (source_x < destination_x) {
            var column: u32 = width;
            while (column > 0) {
                column -= 1;
                self.Base[destination_offset + column] = self.Base[source_offset + column];
            }
        } else {
            var column: u32 = 0;
            while (column < width) : (column += 1) {
                self.Base[destination_offset + column] = self.Base[source_offset + column];
            }
        }
    }
};

pub const Color = struct {
    R: u8,
    G: u8,
    B: u8,
    A: u8,

    pub fn rgb(red: u8, green: u8, blue: u8) Color {
        return Color{ .R = red, .G = green, .B = blue, .A = 0xFF };
    }

    pub fn rgba(red: u8, green: u8, blue: u8, alpha: u8) Color {
        return Color{ .R = red, .G = green, .B = blue, .A = alpha };
    }

    pub fn toPixel(self: Color, format: efi.types.graphics.PixelFormat) u32 {
        return switch (format) {
            .RGB => (@as(u32, self.R) << (2 * @bitSizeOf(u8))) | (@as(u32, self.G) << @bitSizeOf(u8)) | self.B,
            .BGR => (@as(u32, self.B) << (2 * @bitSizeOf(u8))) | (@as(u32, self.G) << @bitSizeOf(u8)) | self.R,
            else => (@as(u32, self.R) << (2 * @bitSizeOf(u8))) | (@as(u32, self.G) << @bitSizeOf(u8)) | self.B,
        };
    }

    pub const BLACK = Color.rgb(0, 0, 0);
    pub const WHITE = Color.rgb(255, 255, 255);
    pub const RED = Color.rgb(255, 0, 0);
    pub const GREEN = Color.rgb(0, 255, 0);
    pub const BLUE = Color.rgb(0, 0, 255);
    pub const CYAN = Color.rgb(0, 255, 255);
    pub const MAGENTA = Color.rgb(255, 0, 255);
    pub const YELLOW = Color.rgb(255, 255, 0);
    pub const GRAY = Color.rgb(128, 128, 128);
    pub const DARK_GRAY = Color.rgb(64, 64, 64);
    pub const LIGHT_GRAY = Color.rgb(192, 192, 192);
};
