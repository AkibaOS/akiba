//! PSF font loading and rendering

const boot = @import("../../boot/multiboot/multiboot.zig");
const psf = @import("../../common/constants/psf.zig");
const int = @import("../../utils/types/int.zig");
const pixel = @import("../../utils/graphics/pixel.zig");
const ptr = @import("../../utils/types/ptr.zig");
const terminal_limits = @import("../../common/limits/terminal.zig");

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

    if (try_init_psf1(data)) return;
    if (try_init_psf2(data)) return;

    return error.InvalidFont;
}

fn try_init_psf1(data: []const u8) bool {
    if (data.len < @sizeOf(PSF1Header)) return false;

    const hdr = ptr.of_const(PSF1Header, @intFromPtr(data.ptr));
    if (hdr.magic != psf.PSF1_MAGIC) return false;

    const num_glyphs = if ((hdr.mode & psf.PSF1_MODE_512) != 0)
        psf.PSF1_GLYPHS_512
    else
        psf.PSF1_GLYPHS_256;

    font_info = FontInfo{
        .width = terminal_limits.DEFAULT_CHAR_WIDTH,
        .height = hdr.charsize,
        .num_glyphs = num_glyphs,
        .bytes_per_glyph = hdr.charsize,
        .glyph_data_offset = @sizeOf(PSF1Header),
    };

    font_data = data;
    return true;
}

fn try_init_psf2(data: []const u8) bool {
    if (data.len < @sizeOf(PSF2Header)) return false;

    const hdr = ptr.of_const(PSF2Header, @intFromPtr(data.ptr));
    if (hdr.magic != psf.PSF2_MAGIC) return false;

    font_info = FontInfo{
        .width = hdr.width,
        .height = hdr.height,
        .num_glyphs = hdr.num_glyphs,
        .bytes_per_glyph = hdr.bytes_per_glyph,
        .glyph_data_offset = hdr.header_size,
    };

    font_data = data;
    return true;
}

fn get_glyph(char: u8) ?[]const u8 {
    const info = font_info orelse return null;
    const data = font_data orelse return null;

    if (char >= info.num_glyphs) return null;

    const offset = info.glyph_data_offset + (char * info.bytes_per_glyph);
    if (offset + info.bytes_per_glyph > data.len) return null;

    return data[offset .. offset + info.bytes_per_glyph];
}

pub fn render_char(char: u8, x: u32, y: u32, fb: boot.FramebufferInfo, c: u32) void {
    const glyph = get_glyph(char) orelse return;
    const info = font_info orelse return;

    var row: u32 = 0;
    while (row < info.height) : (row += 1) {
        if (row >= glyph.len) break;

        const byte = glyph[row];
        var col: u32 = 0;
        while (col < 8) : (col += 1) {
            const bit = 7 - int.u3_of(col);
            if ((byte & (@as(u8, 1) << bit)) != 0) {
                pixel.put(fb, x + col, y + row, c);
            }
        }
    }
}

pub fn render_text(text: []const u8, x: u32, y: u32, fb: boot.FramebufferInfo, c: u32) void {
    const info = font_info orelse return;
    var current_x = x;

    for (text) |char| {
        render_char(char, current_x, y, fb, c);
        current_x += info.width;
    }
}

pub fn get_width() u32 {
    if (font_info) |info| return info.width;
    return terminal_limits.DEFAULT_CHAR_WIDTH;
}

pub fn get_height() u32 {
    if (font_info) |info| return info.height;
    return terminal_limits.DEFAULT_CHAR_HEIGHT;
}
