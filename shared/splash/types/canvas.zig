//! Resolved Splash Canvas

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;
const typeset = @import("shared").typeset;

const Face = font.types.face.Face;
const Surface = graphics.types.surface.Surface;
const TextRenderer = graphics.types.renderer.TextRenderer;
const TextStyle = typeset.types.style.TextStyle;

const layout = splash.constants.layout;

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

    FooterBaseline: i32,
    FooterLeftX: i32,
    FooterRightX: i32,

    BracketLeft: i32,
    BracketRight: i32,
    BracketTop: i32,
    BracketBottom: i32,

    pub fn initialize(surface: Surface, face: Face, renderer: *TextRenderer) Canvas {
        const width: i32 = @intCast(surface.Width);
        const height: i32 = @intCast(surface.Height);

        return Canvas{
            .Surface = surface,
            .Face = face,
            .Renderer = renderer,

            .CentreX = @divTrunc(width, 2),
            .WordmarkBaseline = proportion(height, layout.WORDMARK_BASELINE),
            .RomajiBaseline = proportion(height, layout.ROMAJI_BASELINE),

            .RuleX = @divTrunc(width - layout.RULE_WIDTH, 2),
            .RuleY = proportion(height, layout.RULE_TOP),

            .TrailBaseline = proportion(height, layout.TRAIL_BASELINE),
            .TrailStep = proportion(height, layout.TRAIL_STEP),

            .FooterBaseline = proportion(height, layout.FOOTER_BASELINE),
            .FooterLeftX = proportion(width, layout.FOOTER_MARGIN),
            .FooterRightX = width - proportion(width, layout.FOOTER_MARGIN),

            .BracketLeft = proportion(width, layout.BRACKET_INSET_X),
            .BracketRight = width - proportion(width, layout.BRACKET_INSET_X),
            .BracketTop = proportion(height, layout.BRACKET_INSET_Y),
            .BracketBottom = height - proportion(height, layout.BRACKET_INSET_Y),
        };
    }

    pub fn styleFor(pixel_size: i32, tracking: i32) TextStyle {
        return TextStyle{ .PixelSize = pixel_size, .Tracking = tracking };
    }
};

fn proportion(extent: i32, per_mille: i32) i32 {
    return @divTrunc(extent * per_mille, layout.PER_MILLE);
}
