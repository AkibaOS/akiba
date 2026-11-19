//! Diagnostic Screen Pixel Regressions

const std = @import("std");

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const labels = @import("tests").fast.strings.screen;
const screen = @import("tests").screen;
const typeset = @import("shared").typeset;

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
        try expectStatusTag(&target, geometry.Log, 1, screen.constants.palette.PASSED);
        try expectStatusTag(&target, geometry.Log, 2, screen.constants.palette.RUNNING);
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
        const right = bar.X + bar.Width;
        const percent_cell: Rect = .{ .X = right - 8, .Y = bar.Y, .Width = 8, .Height = bar.Height };
        try std.testing.expect(hasInk(&target, percent_cell));
        const separator: Rect = .{ .X = right - 40, .Y = bar.Y, .Width = 8, .Height = bar.Height };
        try std.testing.expect(!hasInk(&target, separator));
        const boot_hint: Rect = .{ .X = controls.X, .Y = controls.Y, .Width = width / 4 - controls.X, .Height = controls.Height };
        const shutdown_hint: Rect = .{ .X = width / 4, .Y = controls.Y, .Width = width / 8, .Height = controls.Height };
        const cancel_hint: Rect = .{ .X = width / 2, .Y = controls.Y, .Width = controls.X + controls.Width - width / 2, .Height = controls.Height };
        const boot_ink = peakInk(&target, boot_hint);
        const shutdown_ink = peakInk(&target, shutdown_hint);
        try std.testing.expect(boot_ink != 0 and boot_ink <= 128);
        try std.testing.expect(shutdown_ink != 0 and shutdown_ink <= 128);
        const cancel_ink = peakInk(&target, cancel_hint);
        try std.testing.expect(cancel_ink != 0 and cancel_ink <= 128);
        try expectPadding(&target);

        @memcpy(before, pixels);
        try std.testing.expect(screen.model.finish(&progress, .Fail));
        try std.testing.expect(screen.model.complete(&progress));
        try std.testing.expect(screen.render.update(&target, geometry, scratch, text, &progress, 0));
        try expectStatusTag(&target, geometry.Log, 2, screen.constants.palette.FAILED);
        for (percent_cell.Y..percent_cell.Y + percent_cell.Height) |row| {
            const start = row * stride + percent_cell.X;
            try std.testing.expectEqualSlices(u32, before[start..][0..percent_cell.Width], pixels[start..][0..percent_cell.Width]);
        }
        try std.testing.expectEqual(fill, pixels[target.offset(right - 52, bar_y)]);
        try std.testing.expect(!hasInk(&target, separator));
        try std.testing.expect(!hasInk(&target, cancel_hint));
        try std.testing.expect(peakInk(&target, boot_hint) <= 128);
        try std.testing.expect(peakInk(&target, shutdown_hint) <= 128);
        progress.MenuReady = true;
        try std.testing.expect(screen.render.update(&target, geometry, scratch, text, &progress, 0));
        try std.testing.expect(peakInk(&target, boot_hint) > 128);
        try std.testing.expect(peakInk(&target, shutdown_hint) > 128);
        try expectCompleteControls(&target, controls, scratch, text);
        const title_end = target.offset(0, header.Y + header.Height / 2);
        const header_end = target.offset(0, header.Y + header.Height);
        try std.testing.expectEqualSlices(u32, before[0..title_end], pixels[0..title_end]);
        try std.testing.expect(!std.mem.eql(u32, before[title_end..header_end], pixels[title_end..header_end]));
        try expectPadding(&target);
    }
}

pub fn menuCountdown() !void {
    const minimum: u32 = 512;
    const pitch = minimum + 7;
    const geometry = screen.layout.plan(minimum, height).?;
    const controls = geometry.Controls;
    const right_footer: Rect = .{ .X = minimum - 128, .Y = controls.Y, .Width = controls.X + controls.Width - (minimum - 128), .Height = controls.Height };
    const pixels = try allocator.alloc(u32, pitch * height);
    defer allocator.free(pixels);
    const previous = try allocator.alloc(u32, pixels.len);
    defer allocator.free(previous);
    const scratch = try allocator.alloc(u32, minimum * height);
    defer allocator.free(scratch);
    @memset(pixels, guard_pixel);
    var target: Surface = .{ .Base = pixels.ptr, .Width = minimum, .Height = height, .Stride = pitch, .Format = .BGR };
    const face = try font.face.load(graphics.assets.font.HIKARI);
    var renderer = graphics.types.renderer.TextRenderer.initAllocating(allocator);
    defer renderer.deinit();
    const text: screen.types.render.Text = .{ .Face = &face, .Renderer = &renderer };
    var rows: [2]screen.types.model.Row = undefined;
    var progress = screen.model.initialize(&rows, 1);
    try std.testing.expect(screen.render.takeover(&target, geometry, scratch, text, &progress, null));
    try std.testing.expect(peakInk(&target, right_footer) <= 128);
    try std.testing.expect(screen.model.begin(&progress, labels.FIRST_CASE));
    try std.testing.expect(screen.model.finish(&progress, .Pass));
    try std.testing.expect(screen.model.complete(&progress));
    try std.testing.expect(screen.render.update(&target, geometry, scratch, text, &progress, 0));
    try std.testing.expect(!hasInk(&target, right_footer));
    progress.MenuReady = true;
    try std.testing.expect(screen.render.takeover(&target, geometry, scratch, text, &progress, null));
    try expectCountdown(&target, right_footer, scratch, text, "Booting in 30s");
    try expectCompleteControls(&target, controls, scratch, text);
    pixels[target.offset(controls.X, controls.Y)] = guard_pixel;
    @memcpy(previous, pixels);
    try std.testing.expect(screen.render.updateCountdown(&target, geometry, scratch, text, 9));
    try expectCountdown(&target, right_footer, scratch, text, "Booting in 9s");
    for (0..height) |row| {
        for (0..pitch) |column| {
            if (inside(right_footer, column, row)) continue;
            const index = row * pitch + column;
            try std.testing.expectEqual(previous[index], pixels[index]);
        }
    }
}

pub fn activeBootRow() !void {
    const layout = screen.layout.plan(width, height).?;
    const pixels = try allocator.alloc(u32, stride * height);
    defer allocator.free(pixels);
    const before = try allocator.alloc(u32, pixels.len);
    defer allocator.free(before);
    const scratch = try allocator.alloc(u32, width * height);
    defer allocator.free(scratch);
    @memset(pixels, guard_pixel);
    var target: Surface = .{ .Base = pixels.ptr, .Width = width, .Height = height, .Stride = stride, .Format = .RGB };
    const face = try font.face.load(graphics.assets.font.HIKARI);
    var renderer = graphics.types.renderer.TextRenderer.initAllocating(allocator);
    defer renderer.deinit();
    const text: screen.types.render.Text = .{ .Face = &face, .Renderer = &renderer };
    var rows: [4]screen.types.model.Row = undefined;
    var state = screen.model.initialize(&rows, 2);
    try std.testing.expect(screen.model.begin(&state, labels.FIRST_CASE));
    try std.testing.expect(screen.model.beginWork(&state, 4));
    try std.testing.expect(screen.render.takeover(&target, layout, scratch, text, &state, null));
    @memcpy(before, pixels);
    try std.testing.expect(screen.model.checkpoint(&state, 1));
    try std.testing.expect(screen.render.updateActive(&target, layout, scratch, text, &state, 1, true));
    const frame = screen.constants.frame;
    const active: Rect = .{
        .X = layout.Log.X + frame.INSET,
        .Y = layout.Log.Y + frame.INSET + frame.ROW_HEIGHT,
        .Width = layout.Log.Width - 2 * frame.INSET,
        .Height = frame.ROW_HEIGHT,
    };
    var changed_active = false;
    var changed_progress = false;
    for (0..height) |row_index| {
        for (0..stride) |column| {
            const index = row_index * stride + column;
            if (before[index] == pixels[index]) continue;
            if (inside(active, column, row_index)) {
                changed_active = true;
            } else if (inside(layout.Progress, column, row_index)) {
                changed_progress = true;
            } else {
                return error.UnrelatedBootPixelsChanged;
            }
        }
    }
    try std.testing.expect(changed_active and changed_progress);
    try expectPadding(&target);
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

fn expectStatusTag(target: *const Surface, log: Rect, line: u32, tag: graphics.types.color.Color) !void {
    const frame = screen.constants.frame;
    const left = log.X + frame.INSET;
    const label_start = left + 52;
    const top = log.Y + frame.INSET + line * frame.ROW_HEIGHT;
    var status_visible = false;
    var label_visible = false;
    for (top..top + frame.ROW_HEIGHT) |y| {
        for (left..log.X + log.Width - frame.INSET) |x| {
            const color = graphics.types.color.Color.fromPixel(target.Base[target.offset(@intCast(x), @intCast(y))], target.Format);
            if (x < label_start) {
                status_visible = status_visible or std.meta.eql(color, tag);
            } else {
                try std.testing.expect(color.R == color.G and color.G == color.B);
                label_visible = label_visible or color.R != 0;
            }
        }
    }
    try std.testing.expect(status_visible and label_visible);
}

fn expectCompleteControls(target: *const Surface, controls: Rect, scratch: []u32, text: screen.types.render.Text) !void {
    const frame = screen.constants.frame;
    const reference_width = controls.Width - 2 * frame.INSET;
    var reference: Surface = .{ .Base = scratch.ptr, .Width = reference_width, .Height = 2 * controls.Height, .Stride = reference_width, .Format = target.Format };
    graphics.draw.clear(&reference, screen.constants.palette.DESKTOP);
    try graphics.text.drawString(text.Renderer, &reference, text.Face, .{ .PixelSize = frame.CAPTION_SIZE, .Tracking = 0 }, 0, @intCast(controls.Height), screen.strings.text.COMPLETED_LEGEND, screen.constants.palette.TITLE_TEXT, null);
    const expected = inkCount(&reference, .{ .X = 0, .Y = 0, .Width = reference.Width, .Height = reference.Height });
    try std.testing.expect(expected > 0);
    var legend = controls;
    legend.Width -= 128;
    try std.testing.expectEqual(expected, inkCount(target, legend));
}

fn expectCountdown(target: *const Surface, region: Rect, scratch: []u32, text: screen.types.render.Text, message: []const u8) !void {
    const frame = screen.constants.frame;
    const style: typeset.types.style.TextStyle = .{ .PixelSize = frame.CAPTION_SIZE, .Tracking = 0 };
    var reference: Surface = .{ .Base = scratch.ptr, .Width = region.Width, .Height = region.Height, .Stride = region.Width, .Format = target.Format };
    graphics.draw.clear(&reference, screen.constants.palette.DESKTOP);
    const advance = try typeset.measure.advanceWidth(text.Face, style, message);
    const ascent = try typeset.measure.ascent(text.Face, style.PixelSize);
    const descent = try text.Face.pixelMetric(-@as(i32, text.Face.Descender), style.PixelSize);
    const width_pixels: i32 = @intCast(region.Width - frame.INSET);
    const height_pixels: i32 = @intCast(region.Height);
    const baseline = @divTrunc(height_pixels + ascent - descent, 2);
    try graphics.text.drawString(text.Renderer, &reference, text.Face, style, width_pixels - advance, baseline, message, screen.constants.palette.CAPTION, null);
    try std.testing.expect(hasInk(&reference, .{ .X = 0, .Y = 0, .Width = region.Width, .Height = region.Height }));
    for (0..region.Height) |row| {
        const y: u32 = @intCast(row);
        try std.testing.expectEqualSlices(u32, scratch[row * region.Width ..][0..region.Width], target.Base[target.offset(region.X, region.Y + y)..][0..region.Width]);
    }
}

fn inkCount(target: *const Surface, region: Rect) usize {
    var count: usize = 0;
    for (region.Y..region.Y + region.Height) |row| {
        const start = target.offset(region.X, @intCast(row));
        for (target.Base[start..][0..region.Width]) |pixel| count += @intFromBool(pixel != 0);
    }
    return count;
}

fn peakInk(target: *const Surface, region: Rect) u8 {
    var peak: u8 = 0;
    for (region.Y..region.Y + region.Height) |row| {
        const start = target.offset(region.X, @intCast(row));
        for (target.Base[start..][0..region.Width]) |pixel| {
            peak = @max(peak, graphics.types.color.Color.fromPixel(pixel, target.Format).R);
        }
    }
    return peak;
}

fn hasInk(target: *const Surface, region: Rect) bool {
    for (region.Y..region.Y + region.Height) |row| {
        const start = target.offset(region.X, @intCast(row));
        if (!std.mem.allEqual(u32, target.Base[start..][0..region.Width], 0)) return true;
    }
    return false;
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
