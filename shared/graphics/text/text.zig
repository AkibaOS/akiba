//! Outline Text Rendering

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const raster = @import("shared").raster;
const typeset = @import("shared").typeset;

const draw = graphics.draw;

const BlendTarget = graphics.types.renderer.BlendTarget;
const Color = graphics.types.color.Color;
const Cursor = typeset.types.cursor.Cursor;
const Face = font.types.face.Face;
const RowSink = raster.types.sink.RowSink;
const Surface = graphics.types.surface.Surface;
const TextError = graphics.errors.text.TextError;
const TextRenderer = graphics.types.renderer.TextRenderer;
const TextStyle = typeset.types.style.TextStyle;

const limits = raster.constants.limits;

fn writeRow(context: *anyopaque, y: i32, x: i32, coverage: []const u8) void {
    const blend: *BlendTarget = @ptrCast(@alignCast(context));

    for (coverage, 0..) |value, offset| {
        const column = x + @as(i32, @intCast(offset));
        if (value == 0 or !blend.Target.contains(column, y)) continue;
        const background = blend.Background orelse Color.fromPixel(
            blend.Target.Base[blend.Target.offset(@intCast(column), @intCast(y))],
            blend.Target.Format,
        );
        const color = if (value == limits.COVERAGE_FULL)
            blend.Foreground
        else
            background.blend(blend.Foreground, value, @intCast(limits.COVERAGE_FULL));
        draw.putPixel(blend.Target, column, y, color);
    }
}

pub fn drawString(
    renderer: *TextRenderer,
    surface: *Surface,
    face: *const Face,
    style: TextStyle,
    x: i32,
    baseline_y: i32,
    text: []const u8,
    foreground: Color,
    background: ?Color,
) TextError!void {
    var blend = BlendTarget{ .Target = surface, .Foreground = foreground, .Background = background };
    const sink = RowSink{ .Context = &blend, .WriteRow = writeRow };
    const scale = face.scaleFor(style.PixelSize);
    var cursor = Cursor.initialize(face, style, text, x);

    while (try cursor.next()) |placed| {
        try font.outline.load(face, placed.GlyphId, &renderer.Glyphs);
        if (renderer.Glyphs.Shape.ContourCount == 0) continue;
        try raster.flatten.flatten(
            &renderer.Glyphs.Shape,
            scale,
            placed.PenX,
            baseline_y * limits.ONE_PIXEL,
            &renderer.Shape,
        );
        try raster.fill.fill(&renderer.Shape, &renderer.Workspace, sink);
    }
}
