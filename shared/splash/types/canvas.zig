//! Resolved Splash Canvas

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;
const typeset = @import("shared").typeset;

const Face = font.types.face.Face;
const Surface = graphics.types.surface.Surface;
const TextRenderer = graphics.types.renderer.TextRenderer;
const TextStyle = typeset.types.style.TextStyle;

const background = splash.constants.background;
const layout = splash.constants.layout;
const limits = splash.constants.limits;

pub const Canvas = struct {
    Surface: Surface,
    Face: Face,
    Renderer: *TextRenderer,

    CentreX: i32,
    WordmarkBaseline: i32,
    RomajiBaseline: i32,

    RuleX: i32,
    RuleY: i32,

    TrailBaseline: i32,
    TrailStep: i32,
    ActivityFrame: usize,

    FooterBaseline: i32,
    FooterLeftX: i32,
    FooterRightX: i32,

    BracketLeft: i32,
    BracketRight: i32,
    BracketTop: i32,
    BracketBottom: i32,

    BackgroundWidth: i32,
    BackgroundHeight: i32,
    BackgroundOffsetX: i32,
    BackgroundOffsetY: i32,

    pub fn initialize(surface: Surface, face: Face, renderer: *TextRenderer) Canvas {
        const width: i32 = @intCast(surface.Width);
        const height: i32 = @intCast(surface.Height);
        const scaled_width = @as(i64, height) * background.WIDTH;
        const scaled_height = @as(i64, width) * background.HEIGHT;
        const cover_width: i32 = if (scaled_width > scaled_height)
            @intCast(@divTrunc(scaled_width + background.HEIGHT - 1, background.HEIGHT))
        else
            width;
        const cover_height: i32 = if (scaled_height > scaled_width)
            @intCast(@divTrunc(scaled_height + background.WIDTH - 1, background.WIDTH))
        else
            height;

        const wordmark_baseline = proportion(height, layout.WORDMARK_BASELINE, layout.REFERENCE_HEIGHT);
        const romaji_baseline = @max(proportion(height, layout.ROMAJI_BASELINE, layout.REFERENCE_HEIGHT), wordmark_baseline + layout.ROMAJI_MINIMUM_GAP);
        const footer_baseline = proportion(height, layout.FOOTER_BASELINE, layout.REFERENCE_HEIGHT);
        const rule_limit = footer_baseline - layout.FOOTER_SIZE - layout.RULE_FOOTER_GAP - layout.RULE_HEIGHT;
        const rule_top = @min(proportion(height, layout.RULE_TOP, layout.REFERENCE_HEIGHT), rule_limit);
        const trail_baseline = rule_top - layout.RULE_MESSAGE_GAP - layout.TRAIL_STEP * @as(i32, @intCast(limits.TRAIL_LINES - 1));

        return Canvas{
            .Surface = surface,
            .Face = face,
            .Renderer = renderer,
            .CentreX = @divTrunc(width, 2),
            .WordmarkBaseline = wordmark_baseline,
            .RomajiBaseline = romaji_baseline,
            .RuleX = @divTrunc(width - layout.RULE_WIDTH, 2),
            .RuleY = rule_top,
            .TrailBaseline = trail_baseline,
            .TrailStep = layout.TRAIL_STEP,
            .ActivityFrame = 0,
            .FooterBaseline = footer_baseline,
            .FooterLeftX = proportion(width, layout.FOOTER_MARGIN, layout.REFERENCE_WIDTH),
            .FooterRightX = width - proportion(width, layout.FOOTER_MARGIN, layout.REFERENCE_WIDTH),
            .BracketLeft = proportion(width, layout.BRACKET_INSET_X, layout.REFERENCE_WIDTH),
            .BracketRight = width - proportion(width, layout.BRACKET_INSET_X, layout.REFERENCE_WIDTH) - 1,
            .BracketTop = proportion(height, layout.BRACKET_INSET_Y, layout.REFERENCE_HEIGHT),
            .BracketBottom = height - proportion(height, layout.BRACKET_INSET_Y, layout.REFERENCE_HEIGHT) - 1,
            .BackgroundWidth = cover_width,
            .BackgroundHeight = cover_height,
            .BackgroundOffsetX = @divTrunc(cover_width - width, 2),
            .BackgroundOffsetY = @divTrunc(cover_height - height, 2),
        };
    }

    pub fn styleFor(pixel_size: i32, tracking: i32) TextStyle {
        return TextStyle{ .PixelSize = pixel_size, .Tracking = tracking };
    }
};

fn proportion(extent: i32, position: i32, reference: i32) i32 {
    return @intCast(@divTrunc(@as(i64, extent) * position + @divTrunc(reference, 2), reference));
}
