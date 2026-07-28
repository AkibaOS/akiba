//! Resolved Splash Canvas

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const constants = splash.constants;

const Font = graphics.types.font.Font;
const Surface = graphics.types.surface.Surface;

const layout = constants.layout;
const wordmark = constants.wordmark;

pub const Canvas = struct {
    Surface: Surface,
    Font: Font,
    CenterX: i32,
    Scale: i32,
    FooterScale: i32,

    WordmarkX: i32,
    WordmarkY: i32,
    WordmarkScale: i32,

    GhostX: i32,
    GhostY: i32,
    GhostScale: i32,

    LabelY: i32,

    ProgressX: i32,
    ProgressY: i32,
    ProgressWidth: i32,

    TrailY: i32,
    TrailStep: i32,

    FooterY: i32,
    FooterLeftX: i32,
    FooterRightX: i32,

    BracketLeft: i32,
    BracketRight: i32,
    BracketTop: i32,
    BracketBottom: i32,
    BracketArm: i32,

    pub fn initialize(surface: Surface, font: Font) Canvas {
        const width: i32 = @intCast(surface.Width);
        const height: i32 = @intCast(surface.Height);

        const scale = textScale(width);
        const wordmark_width = proportion(width, layout.WORDMARK_WIDTH);
        const wordmark_scale = @divTrunc(wordmark_width * layout.PER_MILLE, wordmark.TOTAL_UNITS);
        const wordmark_y = proportion(height, layout.WORDMARK_TOP);

        const ghost_scale = @divTrunc(wordmark_scale * layout.GHOST_PERCENT, 100);
        const ghost_width = @divTrunc(ghost_scale * wordmark.TOTAL_UNITS, layout.PER_MILLE);
        const progress_width = proportion(width, layout.PROGRESS_WIDTH);

        return Canvas{
            .Surface = surface,
            .Font = font,
            .CenterX = @divTrunc(width, 2),
            .Scale = scale,
            .FooterScale = if (scale > 1) scale - 1 else 1,

            .WordmarkX = @divTrunc(width - wordmark_width, 2),
            .WordmarkY = wordmark_y,
            .WordmarkScale = wordmark_scale,

            .GhostX = @divTrunc(width - ghost_width, 2),
            .GhostY = wordmark_y + @divTrunc(wordmark_scale - ghost_scale, 2),
            .GhostScale = ghost_scale,

            .LabelY = proportion(height, layout.LABEL_TOP),

            .ProgressX = @divTrunc(width - progress_width, 2),
            .ProgressY = proportion(height, layout.PROGRESS_TOP),
            .ProgressWidth = progress_width,

            .TrailY = proportion(height, layout.TRAIL_TOP),
            .TrailStep = proportion(height, layout.TRAIL_STEP),

            .FooterY = proportion(height, layout.FOOTER_TOP),
            .FooterLeftX = proportion(width, layout.FOOTER_LEFT),
            .FooterRightX = proportion(width, layout.FOOTER_RIGHT),

            .BracketLeft = proportion(width, layout.BRACKET_LEFT),
            .BracketRight = proportion(width, layout.BRACKET_RIGHT),
            .BracketTop = proportion(height, layout.BRACKET_TOP),
            .BracketBottom = proportion(height, layout.BRACKET_BOTTOM),
            .BracketArm = proportion(width, layout.BRACKET_ARM),
        };
    }
};

fn proportion(extent: i32, per_mille: i32) i32 {
    return @divTrunc(extent * per_mille, layout.PER_MILLE);
}

fn textScale(width: i32) i32 {
    const derived = @divTrunc(width, layout.SCALE_DIVISOR);
    return if (derived < 1) 1 else derived;
}
