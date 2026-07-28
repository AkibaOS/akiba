//! Text Rendering To Grayscale

const std = @import("std");

const common = @import("common");
const font = @import("shared").font;
const raster = @import("shared").raster;

const utf8 = @import("utils").text.utf8;

const Face = font.types.face.Face;
const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;
const GlyphBuffer = font.types.outline.GlyphBuffer;
const RowSink = raster.types.sink.RowSink;
const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

const limits = raster.constants.limits;

var glyph_buffer: GlyphBuffer = undefined;
var shape: Shape = undefined;
var workspace: Workspace = undefined;

pub const Canvas = struct {
    Pixels: []u8,
    Width: i32,
    Height: i32,
};

fn writeRow(context: *anyopaque, y: i32, x: i32, coverage: []const u8) void {
    const canvas: *Canvas = @ptrCast(@alignCast(context));
    if (y < 0 or y >= canvas.Height) {
        return;
    }

    for (coverage, 0..) |value, offset| {
        const column = x + @as(i32, @intCast(offset));
        if (column < 0 or column >= canvas.Width) {
            continue;
        }
        const index = @as(usize, @intCast(y)) * @as(usize, @intCast(canvas.Width)) + @as(usize, @intCast(column));
        if (value > canvas.Pixels[index]) {
            canvas.Pixels[index] = value;
        }
    }
}

pub fn drawText(
    face: *const Face,
    text: []const u8,
    pixel_size: i32,
    pen_x: i32,
    baseline_y: i32,
    canvas: *Canvas,
) !void {
    const scale = face.scaleFor(pixel_size);
    const sink = RowSink{ .Context = canvas, .WriteRow = writeRow };

    var pen = pen_x * limits.ONE_PIXEL;

    var cursor: usize = 0;
    while (cursor < text.len) {
        const decoded = utf8.decode(text[cursor..]);
        cursor += decoded.Length;

        const glyph_id = try font.charmap.lookup(face.Charmap, decoded.Codepoint);
        try font.outline.load(face, glyph_id, &glyph_buffer);

        if (glyph_buffer.Shape.ContourCount > 0) {
            try raster.flatten.flatten(
                &glyph_buffer.Shape,
                scale,
                pen,
                baseline_y * limits.ONE_PIXEL,
                &shape,
            );
            try raster.fill.fill(&shape, &workspace, sink);
        }

        const advance = try font.metrics.advanceWidth(face, glyph_id);
        pen += scale.applyToUnits(@intCast(advance)).Raw;
    }
}

pub fn writePortableGrayMap(canvas: *const Canvas, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var header: [64]u8 = undefined;
    const written = try std.fmt.bufPrint(&header, "P5\n{d} {d}\n255\n", .{ canvas.Width, canvas.Height });

    try file.writeAll(written);
    try file.writeAll(canvas.Pixels);
}

pub fn scaleFor(face: *const Face, pixel_size: i32) Fixed16Dot16 {
    return face.scaleFor(pixel_size);
}
