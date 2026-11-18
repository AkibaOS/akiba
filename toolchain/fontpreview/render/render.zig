//! Text Rendering To Grayscale

const std = @import("std");

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const preview = @import("fontpreview");
const raster = @import("shared").raster;
const typeset = @import("shared").typeset;

const ArgumentError = preview.errors.arguments.ArgumentError;
const Canvas = preview.types.canvas.Canvas;
const Cursor = typeset.types.cursor.Cursor;
const Face = font.types.face.Face;
const Placement = raster.types.placement.Placement;
const RowSink = raster.types.sink.RowSink;
const TextRenderer = graphics.types.renderer.TextRenderer;

const output = preview.constants.limits;
const strings = preview.strings.render;

pub fn renderText(allocator: std.mem.Allocator, data: []const u8, args: [][:0]u8) !void {
    if (args.len != 8) return ArgumentError.InvalidArgs;

    const pixel_size = try std.fmt.parseInt(i32, args[3], 10);
    const text = args[4];
    const width = try std.fmt.parseInt(i32, args[5], 10);
    const height = try std.fmt.parseInt(i32, args[6], 10);
    const count = try pixelCount(width, height);

    const face = try font.face.load(data);
    const baseline = try typeset.measure.ascent(&face, pixel_size);
    const pixels = try allocator.alloc(u8, count);
    defer allocator.free(pixels);
    @memset(pixels, 0);

    var renderer = TextRenderer.initAllocating(allocator);
    defer renderer.deinit();
    var canvas = Canvas{ .Pixels = pixels, .Width = width, .Height = height };
    try drawText(&renderer, &face, text, pixel_size, 0, baseline, &canvas);
    try writePortableGrayMap(&canvas, args[7]);
}

pub fn drawText(renderer: *TextRenderer, face: *const Face, text: []const u8, pixel_size: i32, pen_x: i32, baseline_y: i32, canvas: *Canvas) !void {
    try validateCanvas(canvas);
    const baseline = try Placement.pixelCoordinate(baseline_y);
    var cursor = try Cursor.initialize(face, .{ .PixelSize = pixel_size, .Tracking = 0 }, text, pen_x);
    const sink = RowSink{
        .Clip = .{ .Right = canvas.Width, .Bottom = canvas.Height },
        .Context = canvas,
        .WriteRow = writeRow,
    };
    while (try cursor.next()) |placed| {
        try graphics.text.drawGlyph(renderer, face, placed.GlyphId, cursor.Scale, placed.PenX, baseline, sink);
    }
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
    const width: usize = @intCast(canvas.Width);
    const row_start = @as(usize, @intCast(y)) * width + @as(usize, @intCast(x));
    for (canvas.Pixels[row_start..][0..coverage.len], coverage) |*pixel, value| {
        pixel.* = @max(pixel.*, value);
    }
}
