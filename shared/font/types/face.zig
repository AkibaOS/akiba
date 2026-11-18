//! Font Face

const std = @import("std");

const common = @import("common");
const font = @import("shared").font;
const sfnt = @import("shared").sfnt;

const Directory = sfnt.types.directory.Directory;
const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;
const FontError = font.errors.font.FontError;

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

    pub fn scaleFor(self: *const Face, pixel_size: i32) FontError!Fixed16Dot16 {
        try self.validatePixelSize(pixel_size);
        return Fixed16Dot16.fromRatio(pixel_size, self.UnitsPerEm) catch return FontError.ScaleOutOfRange;
    }

    pub fn lineHeight(self: *const Face, pixel_size: i32) FontError!i32 {
        const span = @as(i32, self.Ascender) - self.Descender + self.LineGap;
        return self.pixelMetric(span, pixel_size);
    }

    pub fn pixelMetric(self: *const Face, units: i32, pixel_size: i32) FontError!i32 {
        try self.validatePixelSize(pixel_size);
        const scaled = @divTrunc(@as(i64, units) * pixel_size, self.UnitsPerEm);
        return std.math.cast(i32, scaled) orelse FontError.MetricOutOfRange;
    }

    fn validatePixelSize(self: *const Face, pixel_size: i32) FontError!void {
        if (self.UnitsPerEm == 0) return FontError.InvalidUnitsPerEm;
        if (pixel_size <= 0) return FontError.InvalidPixelSize;
    }
};
