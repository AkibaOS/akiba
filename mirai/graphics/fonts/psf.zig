//! PSF font loading and rendering

const boot = @import("../../boot/multiboot2.zig");
const serial = @import("../../drivers/serial.zig");

const PSF1_MAGIC: u16 = 0x0436;
const PSF2_MAGIC: u32 = 0x864ab572;

const PSF1Header = packed struct {
    magic: u16,
    mode: u8,
    charsize: u8,
};

const PSF2Header = packed struct {
    magic: u32,
    version: u32,
    header_size: u32,
    flags: u32,
    num_glyphs: u32,
    bytes_per_glyph: u32,
    height: u32,
    width: u32,
};

const FontInfo = struct {
    width: u32,
    height: u32,
    num_glyphs: u32,
    bytes_per_glyph: u32,
    glyph_data_offset: u32,
};

var font_data: ?[]const u8 = null;
var font_info: ?FontInfo = null;

pub fn init(data: []const u8) !void {
    if (data.len < 4) return error.InvalidFont;

    const magic16 = @as(*const u16, @ptrCast(@alignCast(&data[0]))).*;

    if (magic16 == PSF1_MAGIC) {
        if (data.len < @sizeOf(PSF1Header)) return error.InvalidFont;

        const hdr = @as(*const PSF1Header, @ptrCast(@alignCast(&data[0])));
        const num_glyphs: u32 = if ((hdr.mode & 0x01) != 0) 512 else 256;

        font_info = FontInfo{
            .width = 8,
            .height = hdr.charsize,
            .num_glyphs = num_glyphs,
            .bytes_per_glyph = hdr.charsize,
            .glyph_data_offset = @sizeOf(PSF1Header),
        };

        font_data = data;
        return;
    }

    const magic32 = @as(*const u32, @ptrCast(@alignCast(&data[0]))).*;

    if (magic32 == PSF2_MAGIC) {
        if (data.len < @sizeOf(PSF2Header)) return error.InvalidFont;

        const hdr = @as(*const PSF2Header, @ptrCast(@alignCast(&data[0])));

        font_info = FontInfo{
            .width = hdr.width,
            .height = hdr.height,
            .num_glyphs = hdr.num_glyphs,
            .bytes_per_glyph = hdr.bytes_per_glyph,
            .glyph_data_offset = hdr.header_size,
        };

        font_data = data;
        return;
    }

    return error.InvalidFont;
}

fn get_char_bitmap(char: u8) ?[]const u8 {
    if (font_data == null or font_info == null) return null;

    const info = font_info.?;
    const data = font_data.?;

    if (char >= info.num_glyphs) return null;

    const glyph_offset = info.glyph_data_offset + (char * info.bytes_per_glyph);
    if (glyph_offset + info.bytes_per_glyph > data.len) return null;

    return data[glyph_offset .. glyph_offset + info.bytes_per_glyph];
}

pub fn render_text(text: []const u8, x: u32, y: u32, fb: boot.FramebufferInfo, color: u32) void {
    if (font_info == null) {
        serial.print("psf.render_text: font_info is null!\n");
        return;
    }

    serial.print("psf.render_text: text='");
    for (text) |c| {
        serial.print_hex(c);
        serial.print(" ");
    }
    serial.print("', x=");
    serial.print_hex(x);
    serial.print(", y=");
    serial.print_hex(y);
    serial.print(", fb.addr=");
    serial.print_hex(fb.addr);
    serial.print("\n");

    const info = font_info.?;
    var current_x = x;

    for (text) |char| {
        if (get_char_bitmap(char)) |glyph| {
            render_glyph(glyph, current_x, y, fb, color);
            current_x += info.width;
        }
    }
}

fn render_glyph(glyph: []const u8, x: u32, y: u32, fb: boot.FramebufferInfo, color: u32) void {
    if (font_info == null) return;

    // Handle different bit depths
    if (fb.bpp == 32) {
        render_glyph_32bit(glyph, x, y, fb, color);
    } else if (fb.bpp == 24) {
        render_glyph_24bit(glyph, x, y, fb, color);
    } else {
        // Fallback to 32-bit for other modes
        render_glyph_32bit(glyph, x, y, fb, color);
    }
}

fn render_glyph_32bit(glyph: []const u8, x: u32, y: u32, fb: boot.FramebufferInfo, color: u32) void {
    if (font_info == null) return;

    const info = font_info.?;
    const pixels = @as([*]volatile u32, @ptrFromInt(fb.addr));

    var row: u32 = 0;
    while (row < info.height) : (row += 1) {
        const byte_index = row;
        if (byte_index >= glyph.len) break;

        const byte = glyph[byte_index];

        var col: u32 = 0;
        while (col < 8) : (col += 1) {
            const bit = 7 - col;
            if ((byte & (@as(u8, 1) << @as(u3, @truncate(bit)))) != 0) {
                const px = x + col;
                const py = y + row;
                if (px < fb.width and py < fb.height) {
                    const offset = py * (fb.pitch / 4) + px;
                    pixels[offset] = color;
                }
            }
        }
    }
}

fn render_glyph_24bit(glyph: []const u8, x: u32, y: u32, fb: boot.FramebufferInfo, color: u32) void {
    if (font_info == null) return;

    const info = font_info.?;
    const pixels = @as([*]volatile u8, @ptrFromInt(fb.addr));

    // Extract RGB components
    const r = @as(u8, @truncate((color >> 16) & 0xFF));
    const g = @as(u8, @truncate((color >> 8) & 0xFF));
    const b = @as(u8, @truncate(color & 0xFF));

    var row: u32 = 0;
    while (row < info.height) : (row += 1) {
        const byte_index = row;
        if (byte_index >= glyph.len) break;

        const byte = glyph[byte_index];

        var col: u32 = 0;
        while (col < 8) : (col += 1) {
            const bit = 7 - col;
            if ((byte & (@as(u8, 1) << @as(u3, @truncate(bit)))) != 0) {
                const px = x + col;
                const py = y + row;
                if (px < fb.width and py < fb.height) {
                    // 24-bit mode: 3 bytes per pixel (BGR order)
                    const offset = py * fb.pitch + px * 3;
                    pixels[offset] = b; // Blue
                    pixels[offset + 1] = g; // Green
                    pixels[offset + 2] = r; // Red
                }
            }
        }
    }
}

pub fn get_width() u32 {
    if (font_info) |info| {
        return info.width;
    }
    return 8;
}

pub fn get_height() u32 {
    if (font_info) |info| {
        return info.height;
    }
    return 16;
}
