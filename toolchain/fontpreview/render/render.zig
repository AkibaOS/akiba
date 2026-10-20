//! Text Rendering To Grayscale

const std = @import("std");

const common = @import("common");
const font = @import("shared").font;
const preview = @import("fontpreview");
const raster = @import("shared").raster;
const utf8 = @import("utils").text.utf8;

const Canvas = preview.types.canvas.Canvas;
const Face = font.types.face.Face;
const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;
const GlyphBuffer = font.types.outline.GlyphBuffer;
const RowSink = raster.types.sink.RowSink;
const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

const limits = raster.constants.limits;
const output = preview.constants.limits;
const strings = preview.strings.render;

var glyph_buffer: GlyphBuffer = undefined;
var shape: Shape = undefined;
var workspace: Workspace = undefined;

pub fn renderText(allocator: std.mem.Allocator, data: []const u8, args: [][:0]u8) !void {
    const face = try font.face.load(data);

    const pixel_size = try std.fmt.parseInt(i32, args[3], 10);
    const text = args[4];
    const width = try std.fmt.parseInt(i32, args[5], 10);
    const height = try std.fmt.parseInt(i32, args[6], 10);

    const pixels = try allocator.alloc(u8, @intCast(width * height));
    defer allocator.free(pixels);
    @memset(pixels, 0);

    var canvas = Canvas{ .Pixels = pixels, .Width = width, .Height = height };

    const baseline = @divTrunc(@as(i32, face.Ascender) * pixel_size, @as(i32, face.UnitsPerEm));
    try drawText(&face, text, pixel_size, 0, baseline, &canvas);
    try writePortableGrayMap(&canvas, args[7]);
}

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

    var header: [output.HEADER_BYTES]u8 = undefined;
    const written = try std.fmt.bufPrint(&header, strings.PGM_HEADER, .{ canvas.Width, canvas.Height });

    try file.writeAll(written);
    try file.writeAll(canvas.Pixels);
}

pub fn scaleFor(face: *const Face, pixel_size: i32) Fixed16Dot16 {
    return face.scaleFor(pixel_size);
}
