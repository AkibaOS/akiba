//! Font Face

const common = @import("common");
const sfnt = @import("shared").sfnt;

const Directory = sfnt.directory.Directory;
const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;

pub const Face = struct {
    Directory: Directory,
    UnitsPerEm: u16,
    GlyphCount: u16,
    IndexToLocationFormat: i16,
    Ascender: i16,
    Descender: i16,
    LineGap: i16,
    LongMetricCount: u16,
    Glyf: []const u8,
    Loca: []const u8,
    Hmtx: []const u8,
    Charmap: []const u8,

    pub fn scaleFor(self: *const Face, pixel_size: i32) Fixed16Dot16 {
        return Fixed16Dot16.fromRatio(pixel_size, @intCast(self.UnitsPerEm));
    }

    pub fn lineHeight(self: *const Face, pixel_size: i32) i32 {
        const span: i32 = @as(i32, self.Ascender) - @as(i32, self.Descender) + @as(i32, self.LineGap);
        return @divTrunc(span * pixel_size, @as(i32, self.UnitsPerEm));
    }
};
