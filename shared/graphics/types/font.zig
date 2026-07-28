//! PSF2 Bitmap Font

const graphics = @import("shared").graphics;

const bits = @import("utils").bits;

const constants = graphics.constants.font;

pub const Header = extern struct {
    Magic: u32,
    Version: u32,
    HeaderSize: u32,
    Flags: u32,
    GlyphCount: u32,
    GlyphSize: u32,
    Height: u32,
    Width: u32,

    pub fn isValid(self: *const Header) bool {
        return self.Magic == constants.PSF2_MAGIC;
    }

    pub fn hasUnicodeTable(self: *const Header) bool {
        return (self.Flags & constants.PSF2_FLAG_UNICODE) != 0;
    }

    pub fn bytesPerRow(self: *const Header) u32 {
        return @intCast(bits.operations.bitmapBytes(self.Width));
    }
};

pub const Font = struct {
    Glyphs: [*]const u8,
    GlyphCount: u32,
    GlyphSize: u32,
    Width: u32,
    Height: u32,
    BytesPerRow: u32,

    pub fn load(data: [*]const u8, size: u64) ?Font {
        if (size < @sizeOf(Header)) {
            return null;
        }
        if (@intFromPtr(data) % @alignOf(Header) != 0) {
            return null;
        }

        const header: *const Header = @ptrCast(@alignCast(data));
        if (!header.isValid()) {
            return null;
        }

        return Font{
            .Glyphs = data + header.HeaderSize,
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

    pub fn isGlyphPixelSet(self: *const Font, glyph: [*]const u8, x: u32, y: u32) bool {
        if (x >= self.Width or y >= self.Height) {
            return false;
        }

        const row = glyph + (y * self.BytesPerRow);
        const byte_index = x / @bitSizeOf(u8);
        const bit_index: u3 = @truncate((@bitSizeOf(u8) - 1) - (x % @bitSizeOf(u8)));

        return ((row[byte_index] >> bit_index) & 1) != 0;
    }
};
