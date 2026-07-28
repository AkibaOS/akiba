//! Glyph Cursor

const font = @import("shared").font;
const raster = @import("shared").raster;
const typeset = @import("shared").typeset;

const utf8 = @import("utils").text.utf8;

const Face = font.types.face.Face;
const FontError = font.errors.font.FontError;
const PlacedGlyph = typeset.types.placement.PlacedGlyph;
const TextStyle = typeset.types.style.TextStyle;

const limits = raster.constants.limits;

pub const Cursor = struct {
    Face: *const Face,
    Style: TextStyle,
    Text: []const u8,
    Offset: usize,
    PenX: i32,

    pub fn initialize(face: *const Face, style: TextStyle, text: []const u8, origin_x: i32) Cursor {
        return Cursor{
            .Face = face,
            .Style = style,
            .Text = text,
            .Offset = 0,
            .PenX = origin_x * limits.ONE_PIXEL,
        };
    }

    pub fn next(self: *Cursor) FontError!?PlacedGlyph {
        if (self.Offset >= self.Text.len) {
            return null;
        }

        const decoded = utf8.decode(self.Text[self.Offset..]);
        self.Offset += decoded.Length;

        const glyph_id = try font.charmap.lookup(self.Face.Charmap, decoded.Codepoint);
        const placed = PlacedGlyph{ .GlyphId = glyph_id, .PenX = self.PenX };

        const advance = try font.metrics.advanceWidth(self.Face, glyph_id);
        const scale = self.Face.scaleFor(self.Style.PixelSize);
        self.PenX += scale.applyToUnits(@intCast(advance)).Raw + self.Style.Tracking * limits.ONE_PIXEL;

        return placed;
    }
};
