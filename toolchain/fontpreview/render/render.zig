//! Text Rendering To Grayscale

const std = @import("std");

const common = @import("common");
const font = @import("shared").font;
const preview = @import("fontpreview");
const raster = @import("shared").raster;
const typeset = @import("shared").typeset;

const ArgumentError = preview.errors.arguments.ArgumentError;
const Canvas = preview.types.canvas.Canvas;
const Cursor = typeset.types.cursor.Cursor;
const Face = font.types.face.Face;
const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;
const FontError = font.errors.font.FontError;
const GlyphBuffer = font.types.outline.GlyphBuffer;
const Placement = raster.types.placement.Placement;
const RowSink = raster.types.sink.RowSink;
const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

const output = preview.constants.limits;
const strings = preview.strings.render;

var glyph_buffer: GlyphBuffer = undefined;
var shape: Shape = undefined;
var workspace: Workspace = undefined;

pub fn renderText(allocator: std.mem.Allocator, data: []const u8, args: [][:0]u8) !void {
    if (args.len != 8) return ArgumentError.InvalidArgs;

    const pixel_size = try std.fmt.parseInt(i32, args[3], 10);
    const text = args[4];
    const width = try std.fmt.parseInt(i32, args[5], 10);
    const height = try std.fmt.parseInt(i32, args[6], 10);
    const count = try pixelCount(width, height);

    const face = try font.face.load(data);
    const baseline = try Placement.pixelCoordinate(try typeset.measure.ascent(&face, pixel_size));
    var cursor = try Cursor.initialize(&face, .{ .PixelSize = pixel_size, .Tracking = 0 }, text, 0);

    const pixels = try allocator.alloc(u8, count);
    defer allocator.free(pixels);
    @memset(pixels, 0);

    var canvas = Canvas{ .Pixels = pixels, .Width = width, .Height = height };
    try drawGlyphs(&cursor, baseline, &canvas);
    try writePortableGrayMap(&canvas, args[7]);
}

pub fn drawText(
    face: *const Face,
    text: []const u8,
    pixel_size: i32,
    pen_x: i32,
    baseline_y: i32,
    canvas: *Canvas,
) !void {
    try validateCanvas(canvas);
    const baseline = try Placement.pixelCoordinate(baseline_y);
    var cursor = try Cursor.initialize(face, .{ .PixelSize = pixel_size, .Tracking = 0 }, text, pen_x);
    try drawGlyphs(&cursor, baseline, canvas);
}

pub fn writePortableGrayMap(canvas: *const Canvas, path: []const u8) !void {
    try validateCanvas(canvas);
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var header: [output.HEADER_BYTES]u8 = undefined;
    const written = try std.fmt.bufPrint(&header, strings.PGM_HEADER, .{ canvas.Width, canvas.Height });

    try file.writeAll(written);
    try file.writeAll(canvas.Pixels);
}

pub fn scaleFor(face: *const Face, pixel_size: i32) FontError!Fixed16Dot16 {
    return face.scaleFor(pixel_size);
}

fn drawGlyphs(cursor: *Cursor, baseline: i32, canvas: *Canvas) !void {
    const sink = RowSink{ .Context = canvas, .WriteRow = writeRow };

    while (try cursor.next()) |placed| {
        try font.outline.load(cursor.Face, placed.GlyphId, &glyph_buffer);
        if (glyph_buffer.Shape.ContourCount == 0) continue;
        try raster.flatten.flatten(&glyph_buffer.Shape, cursor.Scale, placed.PenX, baseline, &shape);
        try raster.fill.fill(&shape, &workspace, sink);
    }
}

fn pixelCount(width: i32, height: i32) ArgumentError!usize {
    if (width <= 0 or height <= 0) return ArgumentError.InvalidArgs;
    return std.math.mul(usize, @intCast(width), @intCast(height)) catch return ArgumentError.InvalidArgs;
}

fn validateCanvas(canvas: *const Canvas) ArgumentError!void {
    const count = try pixelCount(canvas.Width, canvas.Height);
    if (canvas.Pixels.len != count) return ArgumentError.InvalidArgs;
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
