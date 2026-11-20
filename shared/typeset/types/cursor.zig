//! Glyph Cursor

const std = @import("std");

const common = @import("common");
const font = @import("shared").font;
const raster = @import("shared").raster;
const typeset = @import("shared").typeset;
const utf8 = @import("utils").text.utf8;

const CoordinateError = raster.errors.raster.CoordinateError;
const Face = font.types.face.font.Face;
const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;
const FontError = font.errors.font.FontError;
const PlacedGlyph = typeset.types.placement.PlacedGlyph;
const Placement = raster.types.placement.Placement;
const TextStyle = typeset.types.style.TextStyle;

const limits = raster.constants.limits;

pub const Cursor = struct {
    Face: *const Face,
    Scale: Fixed16Dot16,
    Tracking: i32,
    Text: []const u8,
    Offset: usize,
    PenX: i32,

    pub fn initialize(face: *const Face, style: TextStyle, text: []const u8, origin_x: i32) (FontError || CoordinateError)!Cursor {
        return Cursor{
            .Face = face,
            .Scale = try face.scaleFor(style.PixelSize),
            .Tracking = style.Tracking,
            .Text = text,
            .Offset = 0,
            .PenX = try Placement.pixelCoordinate(origin_x),
        };
    }

    pub fn next(self: *Cursor) (FontError || CoordinateError)!?PlacedGlyph {
        if (self.Offset >= self.Text.len) {
            return null;
        }

        const decoded = utf8.decode(self.Text[self.Offset..]);
        const glyph_id = try font.charmap.lookupFace(self.Face, decoded.Codepoint);
        const placed = PlacedGlyph{ .GlyphId = glyph_id, .PenX = self.PenX };

        const advance = try font.metrics.advanceWidth(self.Face, glyph_id);
        const tracking = @as(i64, self.Tracking) * limits.ONE_PIXEL;
        const pen = @as(i64, self.PenX) + self.Scale.applyToUnitsRawWide(advance) + tracking;
        self.PenX = std.math.cast(i32, pen) orelse return CoordinateError.CoordinateOutOfRange;
        self.Offset += decoded.Length;

        return placed;
    }
};
