//! Splash Text Measurement

const splash = @import("shared").splash;
const typeset = @import("shared").typeset;

const Canvas = splash.types.canvas.Canvas;
const TextError = @import("shared").graphics.errors.text.TextError;
const TextStyle = typeset.types.style.TextStyle;

pub fn width(canvas: *Canvas, style: TextStyle, text: []const u8) TextError!i32 {
    return typeset.measure.advanceWidth(&canvas.Face, style, text);
}

pub fn centredOrigin(canvas: *Canvas, style: TextStyle, text: []const u8) TextError!i32 {
    const measured = try width(canvas, style, text);
    return canvas.CentreX - @divTrunc(measured, 2);
}
