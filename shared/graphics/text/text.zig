//! Bitmap Text Rendering

const graphics = @import("shared").graphics;

const draw = graphics.draw;

const Color = graphics.types.color.Color;
const Font = graphics.types.font.Font;
const Surface = graphics.types.surface.Surface;

pub fn drawGlyph(
    surface: *Surface,
    font: *const Font,
    x: i32,
    y: i32,
    codepoint: u32,
    color: Color,
    scale: i32,
) void {
    const glyph = font.getGlyph(codepoint) orelse return;

    var row: u32 = 0;
    while (row < font.Height) : (row += 1) {
        var column: u32 = 0;
        while (column < font.Width) : (column += 1) {
            if (!font.isGlyphPixelSet(glyph, column, row)) {
                continue;
            }
            draw.fillRect(
                surface,
                x + @as(i32, @intCast(column)) * scale,
                y + @as(i32, @intCast(row)) * scale,
                scale,
                scale,
                color,
            );
        }
    }
}

pub fn drawString(
    surface: *Surface,
    font: *const Font,
    x: i32,
    y: i32,
    message: []const u8,
    color: Color,
    scale: i32,
) void {
    drawSpacedString(surface, font, x, y, message, color, scale, 0);
}

pub fn drawSpacedString(
    surface: *Surface,
    font: *const Font,
    x: i32,
    y: i32,
    message: []const u8,
    color: Color,
    scale: i32,
    spacing: i32,
) void {
    const advance = glyphAdvance(font, scale, spacing);
    var pen = x;
    for (message) |character| {
        drawGlyph(surface, font, pen, y, character, color, scale);
        pen += advance;
    }
}

pub fn measureString(font: *const Font, message: []const u8, scale: i32) i32 {
    return measureSpacedString(font, message, scale, 0);
}

pub fn measureSpacedString(font: *const Font, message: []const u8, scale: i32, spacing: i32) i32 {
    if (message.len == 0) {
        return 0;
    }
    const advance = glyphAdvance(font, scale, spacing);
    return advance * @as(i32, @intCast(message.len)) - spacing;
}

pub fn lineHeight(font: *const Font, scale: i32) i32 {
    return @as(i32, @intCast(font.Height)) * scale;
}

fn glyphAdvance(font: *const Font, scale: i32, spacing: i32) i32 {
    return @as(i32, @intCast(font.Width)) * scale + spacing;
}
