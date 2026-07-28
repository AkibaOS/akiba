//! Wordmark Rendering

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const constants = splash.constants;

const Canvas = splash.types.canvas.Canvas;
const Color = graphics.types.color.Color;
const Quad = graphics.types.geometry.Quad;
const Stripe = graphics.types.geometry.Stripe;

const geometry = constants.wordmark;
const layout = constants.layout;
const palette = constants.palette;

pub fn draw(canvas: *Canvas, origin_x: i32, origin_y: i32, unit_scale: i32, color: Color, stripe: ?Stripe) void {
    var pen = origin_x;

    for (geometry.GLYPHS) |glyph| {
        for (glyph.Strokes) |stroke| {
            var quad: Quad = undefined;
            var corner: usize = 0;
            while (corner < quad.len) : (corner += 1) {
                quad[corner] = .{
                    .X = pen + @divTrunc(stroke[corner].X * unit_scale, geometry.GLYPH_BOX),
                    .Y = origin_y + @divTrunc(stroke[corner].Y * unit_scale, geometry.GLYPH_BOX),
                };
            }
            graphics.draw.fillQuad(&canvas.Surface, quad, color, stripe);
        }
        pen += @divTrunc((glyph.Extent + geometry.GLYPH_GAP) * unit_scale, geometry.GLYPH_BOX);
    }
}

pub fn drawGhost(canvas: *Canvas) void {
    draw(canvas, canvas.GhostX, canvas.GhostY, canvas.GhostScale, palette.GHOST_KANJI, null);
}

pub fn drawCore(canvas: *Canvas) void {
    const stripe = Stripe{ .Period = layout.STRIPE_PERIOD, .Gap = layout.STRIPE_GAP };
    const fringe = @divTrunc(canvas.WordmarkScale * layout.FRINGE_OFFSET, layout.PER_MILLE);

    draw(canvas, canvas.WordmarkX - fringe, canvas.WordmarkY, canvas.WordmarkScale, palette.FRINGE_CYAN, stripe);
    draw(canvas, canvas.WordmarkX + fringe, canvas.WordmarkY, canvas.WordmarkScale, palette.FRINGE_MAGENTA, stripe);
    draw(canvas, canvas.WordmarkX, canvas.WordmarkY, canvas.WordmarkScale, palette.WORDMARK_CORE, stripe);
}
