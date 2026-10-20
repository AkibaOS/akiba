//! Hikari Menu Theme

const Color = @import("shared").graphics.types.color.Color;

pub const Theme = struct {
    Background: Color,
    Foreground: Color,
    HighlightBackground: Color,
    HighlightForeground: Color,
    TitleForeground: Color,
    Border: Color,
    Shadow: Color,
    Success: Color,
    Warning: Color,
    ErrorColor: Color,
};
