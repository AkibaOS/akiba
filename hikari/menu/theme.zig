//! Hikari Menu Theme

const display = @import("../display/display.zig");

pub const Theme = struct {
    background: display.Color,
    foreground: display.Color,
    highlight_bg: display.Color,
    highlight_fg: display.Color,
    title_fg: display.Color,
    border: display.Color,
    shadow: display.Color,
    success: display.Color,
    warning: display.Color,
    error_color: display.Color,

    pub const default = Theme{
        .background = display.Color.rgb(20, 20, 30),
        .foreground = display.Color.rgb(220, 220, 230),
        .highlight_bg = display.Color.rgb(80, 60, 140),
        .highlight_fg = display.Color.rgb(255, 255, 255),
        .title_fg = display.Color.rgb(180, 140, 255),
        .border = display.Color.rgb(60, 50, 80),
        .shadow = display.Color.rgb(10, 10, 15),
        .success = display.Color.rgb(80, 200, 120),
        .warning = display.Color.rgb(255, 200, 80),
        .error_color = display.Color.rgb(255, 80, 80),
    };

    pub const light = Theme{
        .background = display.Color.rgb(240, 240, 245),
        .foreground = display.Color.rgb(30, 30, 40),
        .highlight_bg = display.Color.rgb(100, 80, 180),
        .highlight_fg = display.Color.rgb(255, 255, 255),
        .title_fg = display.Color.rgb(60, 40, 120),
        .border = display.Color.rgb(180, 180, 190),
        .shadow = display.Color.rgb(200, 200, 210),
        .success = display.Color.rgb(40, 160, 80),
        .warning = display.Color.rgb(200, 150, 40),
        .error_color = display.Color.rgb(200, 60, 60),
    };

    pub const akiba = Theme{
        .background = display.Color.rgb(15, 0, 30),
        .foreground = display.Color.rgb(255, 120, 200),
        .highlight_bg = display.Color.rgb(255, 0, 128),
        .highlight_fg = display.Color.rgb(255, 255, 255),
        .title_fg = display.Color.rgb(0, 255, 255),
        .border = display.Color.rgb(128, 0, 255),
        .shadow = display.Color.rgb(5, 0, 10),
        .success = display.Color.rgb(0, 255, 128),
        .warning = display.Color.rgb(255, 255, 0),
        .error_color = display.Color.rgb(255, 0, 64),
    };
};
