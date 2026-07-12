//! Hikari Menu Theme

const display = @import("../../display/display.zig");

const Color = display.framebuffer.Color;

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

    pub const DEFAULT = Theme{
        .Background = Color.rgb(20, 20, 30),
        .Foreground = Color.rgb(220, 220, 230),
        .HighlightBackground = Color.rgb(80, 60, 140),
        .HighlightForeground = Color.rgb(255, 255, 255),
        .TitleForeground = Color.rgb(180, 140, 255),
        .Border = Color.rgb(60, 50, 80),
        .Shadow = Color.rgb(10, 10, 15),
        .Success = Color.rgb(80, 200, 120),
        .Warning = Color.rgb(255, 200, 80),
        .ErrorColor = Color.rgb(255, 80, 80),
    };

    pub const LIGHT = Theme{
        .Background = Color.rgb(240, 240, 245),
        .Foreground = Color.rgb(30, 30, 40),
        .HighlightBackground = Color.rgb(100, 80, 180),
        .HighlightForeground = Color.rgb(255, 255, 255),
        .TitleForeground = Color.rgb(60, 40, 120),
        .Border = Color.rgb(180, 180, 190),
        .Shadow = Color.rgb(200, 200, 210),
        .Success = Color.rgb(40, 160, 80),
        .Warning = Color.rgb(200, 150, 40),
        .ErrorColor = Color.rgb(200, 60, 60),
    };

    pub const AKIBA = Theme{
        .Background = Color.rgb(15, 0, 30),
        .Foreground = Color.rgb(255, 120, 200),
        .HighlightBackground = Color.rgb(255, 0, 128),
        .HighlightForeground = Color.rgb(255, 255, 255),
        .TitleForeground = Color.rgb(0, 255, 255),
        .Border = Color.rgb(128, 0, 255),
        .Shadow = Color.rgb(5, 0, 10),
        .Success = Color.rgb(0, 255, 128),
        .Warning = Color.rgb(255, 255, 0),
        .ErrorColor = Color.rgb(255, 0, 64),
    };
};
