//! Hikari PSF2 Font

const constants = @import("constants/constants.zig");

const bits = @import("utils").bits;

pub const PSF2Header = extern struct {
    Magic: u32,
    Version: u32,
    HeaderSize: u32,
    Flags: u32,
    GlyphCount: u32,
    GlyphSize: u32,
    Height: u32,
    Width: u32,

    pub fn isValid(self: *const PSF2Header) bool {
        return self.Magic == constants.font.PSF2_MAGIC;
    }

    pub fn hasUnicodeTable(self: *const PSF2Header) bool {
        return (self.Flags & constants.font.PSF2_FLAG_UNICODE) != 0;
    }

    pub fn bytesPerRow(self: *const PSF2Header) u32 {
        return @intCast(bits.operations.bitmapBytes(self.Width));
    }
};

pub const Font = struct {
    Header: *const PSF2Header,
    Glyphs: [*]const u8,
    GlyphCount: u32,
    GlyphSize: u32,
    Width: u32,
    Height: u32,
    BytesPerRow: u32,

    pub fn load(data: [*]const u8, size: u64) ?Font {
        if (size < @sizeOf(PSF2Header)) {
            return null;
        }

        const header: *const PSF2Header = @ptrCast(@alignCast(data));

        if (!header.isValid()) {
            return null;
        }

        const glyphs = data + header.HeaderSize;

        return Font{
            .Header = header,
            .Glyphs = glyphs,
            .GlyphCount = header.GlyphCount,
            .GlyphSize = header.GlyphSize,
            .Width = header.Width,
            .Height = header.Height,
            .BytesPerRow = header.bytesPerRow(),
        };
    }

    pub fn getGlyph(self: *const Font, codepoint: u32) ?[*]const u8 {
        if (codepoint >= self.GlyphCount) {
            return null;
        }

        return self.Glyphs + (codepoint * self.GlyphSize);
    }

    pub fn getGlyphPixel(self: *const Font, glyph: [*]const u8, x: u32, y: u32) bool {
        if (x >= self.Width or y >= self.Height) {
            return false;
        }

        const row = glyph + (y * self.BytesPerRow);
        const byte_index = x / @bitSizeOf(u8);
        const bit_index: u3 = @truncate((@bitSizeOf(u8) - 1) - (x % @bitSizeOf(u8)));

        return ((row[byte_index] >> bit_index) & 1) != 0;
    }
};
