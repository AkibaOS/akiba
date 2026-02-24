//! Hikari PSF2 Font

pub const psf2_magic: u32 = 0x864AB572;

pub const Psf2Header = extern struct {
    magic: u32,
    version: u32,
    header_size: u32,
    flags: u32,
    glyph_count: u32,
    glyph_size: u32,
    height: u32,
    width: u32,

    pub fn is_valid(self: *const Psf2Header) bool {
        return self.magic == psf2_magic;
    }

    pub fn has_unicode_table(self: *const Psf2Header) bool {
        return (self.flags & 0x01) != 0;
    }

    pub fn bytes_per_row(self: *const Psf2Header) u32 {
        return (self.width + 7) / 8;
    }
};

pub const Font = struct {
    header: *const Psf2Header,
    glyphs: [*]const u8,
    glyph_count: u32,
    glyph_size: u32,
    width: u32,
    height: u32,
    bytes_per_row: u32,

    pub fn load(data: [*]const u8, size: u64) ?Font {
        if (size < @sizeOf(Psf2Header)) {
            return null;
        }

        const header: *const Psf2Header = @ptrCast(@alignCast(data));

        if (!header.is_valid()) {
            return null;
        }

        const glyphs = data + header.header_size;

        return Font{
            .header = header,
            .glyphs = glyphs,
            .glyph_count = header.glyph_count,
            .glyph_size = header.glyph_size,
            .width = header.width,
            .height = header.height,
            .bytes_per_row = header.bytes_per_row(),
        };
    }

    pub fn get_glyph(self: *const Font, codepoint: u32) ?[*]const u8 {
        if (codepoint >= self.glyph_count) {
            return null;
        }

        return self.glyphs + (codepoint * self.glyph_size);
    }

    pub fn get_glyph_pixel(self: *const Font, glyph: [*]const u8, x: u32, y: u32) bool {
        if (x >= self.width or y >= self.height) {
            return false;
        }

        const row = glyph + (y * self.bytes_per_row);
        const byte_index = x / 8;
        const bit_index: u3 = @truncate(7 - (x % 8));

        return ((row[byte_index] >> bit_index) & 1) != 0;
    }
};
