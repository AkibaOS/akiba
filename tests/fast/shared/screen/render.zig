//! Diagnostic Screen Pixel Regressions

const std = @import("std");

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const labels = @import("tests").strings.screen;
const screen = @import("tests").screen;

const Rect = screen.types.geometry.Rect;
const Surface = graphics.types.surface.Surface;
const allocator = std.testing.allocator;
const guard_pixel: u32 = 0xa76b45da;
const width: u32 = 640;
const height: u32 = 480;
const stride: u32 = width + 7;

pub fn fixedChrome() !void {
    const geometry = screen.layout.plan(width, height).?;
    try std.testing.expect(screen.layout.plan(width, 120) == null);
    const pixels = try allocator.alloc(u32, stride * height);
    defer allocator.free(pixels);
    const before = try allocator.alloc(u32, pixels.len);
    defer allocator.free(before);
    const scratch = try allocator.alloc(u32, width * height);
    defer allocator.free(scratch);
    const face = try font.face.load(graphics.assets.font.HIKARI);
    var renderer = graphics.types.renderer.TextRenderer.initAllocating(allocator);
    defer renderer.deinit();
    const text: screen.types.render.Text = .{ .Face = &face, .Renderer = &renderer };
    for ([_]graphics.types.pixel.PixelFormat{ .RGB, .BGR }) |format| {
        @memset(pixels, guard_pixel);
        var target: Surface = .{ .Base = pixels.ptr, .Width = width, .Height = height, .Stride = stride, .Format = format };
        var rows: [4]screen.types.model.Row = undefined;
        var progress = screen.model.initialize(&rows, 2);
        try std.testing.expect(screen.render.takeover(&target, geometry, scratch, text, &progress, null));
        const header = geometry.Header;
        const black = graphics.types.color.Color.rgb(0, 0, 0).toPixel(format);
        const blue = graphics.types.color.Color.rgb(0, 0, 170).toPixel(format);
        try std.testing.expectEqual(black, pixels[0]);
        try std.testing.expectEqual(black, pixels[target.offset(header.X, header.Y)]);
        try std.testing.expectEqual(blue, pixels[target.offset(header.X + header.Width - 8, header.Y + 8)]);
        const controls = geometry.Controls;
        try std.testing.expectEqual(black, pixels[target.offset(controls.X + controls.Width - 4, controls.Y + 4)]);
        try expectPadding(&target);
        @memcpy(before, pixels);
        try std.testing.expect(screen.model.begin(&progress, labels.FIRST_CASE));
        try std.testing.expect(screen.model.finish(&progress, .Pass));
        try std.testing.expect(screen.model.begin(&progress, labels.NEXT_CASE));
        try std.testing.expect(screen.render.update(&target, geometry, scratch, text, &progress, 3));
        try std.testing.expect(!std.mem.eql(u32, pixels, before));
        for (0..height) |row_index| {
            for (0..stride) |column| {
                if (inside(geometry.Log, column, row_index) or inside(geometry.Progress, column, row_index)) continue;
                const index = row_index * stride + column;
                try std.testing.expectEqual(before[index], pixels[index]);
            }
        }
        const bar = geometry.Progress;
        const bar_y = bar.Y + bar.Height / 2;
        const fill = screen.constants.palette.BAR_FILL.toPixel(format);
        try std.testing.expectEqual(fill, pixels[target.offset(bar.X + 10, bar_y)]);
        try std.testing.expectEqual(black, pixels[target.offset(bar.X + 15, bar_y)]);
        try std.testing.expectEqual(fill, pixels[target.offset(bar.X + 18, bar_y)]);
        try std.testing.expectEqual(black, pixels[target.offset(bar.X + bar.Width * 2 / 3, bar_y)]);
        try expectPadding(&target);

        @memcpy(before, pixels);
        try std.testing.expect(screen.model.finish(&progress, .Pass));
        try std.testing.expect(screen.model.complete(&progress));
        try std.testing.expect(screen.render.update(&target, geometry, scratch, text, &progress, 0));
        const title_end = target.offset(0, header.Y + header.Height / 2);
        const header_end = target.offset(0, header.Y + header.Height);
        try std.testing.expectEqualSlices(u32, before[0..title_end], pixels[0..title_end]);
        try std.testing.expect(!std.mem.eql(u32, before[title_end..header_end], pixels[title_end..header_end]));
        try expectPadding(&target);
    }
}

pub fn failedComposition() !void {
    const geometry = screen.layout.plan(width, height).?;
    const pixels = try allocator.alloc(u32, stride * height);
    defer allocator.free(pixels);
    const before = try allocator.alloc(u32, pixels.len);
    defer allocator.free(before);
    const scratch = try allocator.alloc(u32, width * height);
    defer allocator.free(scratch);
    @memset(pixels, guard_pixel);
    @memset(scratch, guard_pixel);
    var target: Surface = .{ .Base = pixels.ptr, .Width = width, .Height = height, .Stride = stride, .Format = .BGR };
    const face = try font.face.load(graphics.assets.font.HIKARI);
    var damaged = face;
    damaged.Glyf = &.{};
    var renderer = graphics.types.renderer.TextRenderer.initAllocating(allocator);
    defer renderer.deinit();
    var rows: [3]screen.types.model.Row = undefined;
    var progress = screen.model.initialize(&rows, 1);
    try std.testing.expect(!screen.render.takeover(&target, geometry, scratch, .{ .Face = &damaged, .Renderer = &renderer }, &progress, null));
    try std.testing.expect(scratch[0] != guard_pixel);
    try std.testing.expect(std.mem.allEqual(u32, pixels, guard_pixel));
    try std.testing.expect(screen.render.takeover(&target, geometry, scratch, .{ .Face = &face, .Renderer = &renderer }, &progress, null));
    @memcpy(before, pixels);
    try std.testing.expect(screen.model.begin(&progress, labels.FIRST_CASE));
    try std.testing.expect(!screen.render.update(&target, geometry, scratch, .{ .Face = &damaged, .Renderer = &renderer }, &progress, 1));
    try std.testing.expectEqualSlices(u32, before, pixels);
}

pub fn fallbackTitle() !void {
    const minimum = screen.constants.frame.MINIMUM_WIDTH;
    const geometry = screen.layout.plan(minimum, height).?;
    const pixels = try allocator.alloc(u32, minimum * height);
    defer allocator.free(pixels);
    const expected = try allocator.alloc(u32, pixels.len);
    defer allocator.free(expected);
    const scratch = try allocator.alloc(u32, pixels.len);
    defer allocator.free(scratch);
    var target: Surface = .{ .Base = pixels.ptr, .Width = minimum, .Height = height, .Stride = minimum, .Format = .RGB };
    const face = try font.face.load(graphics.assets.font.HIKARI);
    var renderer = graphics.types.renderer.TextRenderer.initAllocating(allocator);
    defer renderer.deinit();
    const text: screen.types.render.Text = .{ .Face = &face, .Renderer = &renderer };
    var rows: [1]screen.types.model.Row = undefined;
    const state = screen.model.initialize(&rows, 1);
    try std.testing.expect(screen.render.takeover(&target, geometry, scratch, text, &state, labels.UNKNOWN_DATE));
    @memcpy(expected, pixels);
    try std.testing.expect(screen.render.takeover(&target, geometry, scratch, text, &state, labels.UNCLOSED_DATE));
    try std.testing.expect(!std.mem.eql(u32, expected, pixels));
    try std.testing.expect(screen.render.takeover(&target, geometry, scratch, text, &state, null));
    try std.testing.expectEqualSlices(u32, expected, pixels);
}

fn expectPadding(target: *const Surface) !void {
    for (0..target.Height) |row_index| {
        const offset = row_index * target.Stride + target.Width;
        try std.testing.expect(std.mem.allEqual(u32, target.Base[offset..][0 .. target.Stride - target.Width], guard_pixel));
    }
}

fn inside(rectangle: Rect, x: usize, y: usize) bool {
    return x >= rectangle.X and x < rectangle.X + rectangle.Width and y >= rectangle.Y and y < rectangle.Y + rectangle.Height;
}
