//! Buffered Diagnostic Screen Rendering

const std = @import("std");

const frame = @import("tests").screen.constants.frame;
const graphics = @import("shared").graphics;
const limits = @import("shared").raster.constants.limits;
const model = @import("tests").screen.model;
const palette = @import("tests").screen.constants.palette;
const phase = @import("tests").phase.constants.menu.frame;
const planner = @import("tests").screen.layout;
const strings = @import("tests").screen.strings.text;
const types = @import("tests").screen.types;
const typeset = @import("shared").typeset;

const Color = graphics.types.color.Color;
const Layout = types.geometry.Layout;
const Rect = types.geometry.Rect;
const Surface = graphics.types.surface.Surface;
const Text = types.render.text.Text;

pub fn takeover(target: *Surface, layout: Layout, scratch: []u32, text: Text, state: *const types.model.state.Model, date: ?[]const u8) bool {
    var staging = prepare(target, layout, scratch) orelse return false;
    graphics.draw.clear(&staging, palette.DESKTOP);
    chrome(&staging, layout, text, date orelse strings.UNKNOWN_DATE, state) catch return false;
    viewport(&staging, layout, text, state, 0) catch return false;
    progress(&staging, layout.Progress, text, state) catch return false;
    commit(target, &staging, .{ .X = 0, .Y = 0, .Width = layout.Width, .Height = layout.Height });
    return true;
}

pub fn update(target: *Surface, layout: Layout, scratch: []u32, text: Text, state: *const types.model.state.Model, animation_frame: usize) bool {
    var staging = prepare(target, layout, scratch) orelse return false;
    viewport(&staging, layout, text, state, animation_frame) catch return false;
    progress(&staging, layout.Progress, text, state) catch return false;
    if (state.Done) {
        subtitle(&staging, layout.Header, text, state) catch return false;
        controls(&staging, layout.Controls, text, state) catch return false;
    }
    commit(target, &staging, layout.Log);
    commit(target, &staging, layout.Progress);
    if (state.Done) {
        commit(target, &staging, subtitleRegion(layout.Header));
        commit(target, &staging, layout.Controls);
    }
    return true;
}

pub fn updateActive(target: *Surface, layout: Layout, scratch: []u32, text: Text, state: *const types.model.state.Model, animation_frame: usize, repaint_progress: bool) bool {
    var staging = prepare(target, layout, scratch) orelse return false;
    const index = model.activeIndex(state) orelse return false;
    if (index >= layout.VisibleRows) return false;
    const entry = model.row(state, index) orelse return false;
    const rectangle: Rect = .{
        .X = layout.Log.X + frame.INSET,
        .Y = layout.Log.Y + frame.INSET + @as(u32, @intCast(index)) * frame.ROW_HEIGHT,
        .Width = layout.Log.Width - 2 * frame.INSET,
        .Height = frame.ROW_HEIGHT,
    };
    var line = scoped(&staging, rectangle);
    graphics.draw.clear(&line, palette.TERMINAL);
    renderRow(&line, text, entry, animation_frame) catch return false;
    if (repaint_progress) progress(&staging, layout.Progress, text, state) catch return false;
    commit(target, &staging, rectangle);
    if (repaint_progress) commit(target, &staging, layout.Progress);
    return true;
}

pub fn updateCountdown(target: *Surface, layout: Layout, scratch: []u32, text: Text, seconds: u8) bool {
    if (seconds == 0 or seconds > phase.COUNTDOWN_SECONDS) return false;
    var staging = prepare(target, layout, scratch) orelse return false;
    const region = countdownRegion(layout.Controls);
    const baseline = captionBaseline(text, region.Height) catch return false;
    paintCountdown(&staging, region, text, baseline, seconds) catch return false;
    commit(target, &staging, region);
    return true;
}

fn prepare(target: *const Surface, layout: Layout, scratch: []u32) ?Surface {
    const expected = planner.plan(target.Width, target.Height) orelse return null;
    if (!std.meta.eql(expected, layout) or target.Stride < target.Width or
        (target.Format != .RGB and target.Format != .BGR)) return null;
    const pixels = std.math.mul(usize, layout.Width, layout.Height) catch return null;
    if (scratch.len < pixels) return null;
    return .{ .Base = scratch.ptr, .Width = layout.Width, .Height = layout.Height, .Stride = layout.Width, .Format = target.Format };
}

fn chrome(staging: *Surface, layout: Layout, text: Text, date: []const u8, state: *const types.model.state.Model) !void {
    var header = panel(staging, layout.Header, palette.TITLE_BAR);
    var title = inset(&header, frame.INSET, frame.BORDER);
    const date_x = try drawFitted(&title, text, frame.TITLE_SIZE, 0, frame.TITLE_BASELINE, strings.TITLE, palette.TITLE_TEXT);
    _ = try drawFitted(&title, text, frame.TITLE_SIZE, date_x, frame.TITLE_BASELINE, date, palette.TITLE_TEXT);
    try subtitle(staging, layout.Header, text, state);
    try controls(staging, layout.Controls, text, state);
}

fn controls(staging: *Surface, rectangle: Rect, text: Text, state: *const types.model.state.Model) !void {
    var strip = scoped(staging, rectangle);
    graphics.draw.clear(&strip, palette.DESKTOP);
    var caption = inset(&strip, frame.INSET, 0);
    const baseline = try captionBaseline(text, caption.Height);
    if (state.MenuReady) caption.Width -= frame.COUNTDOWN_WIDTH;
    const boot_color = if (state.MenuReady) palette.ACTIVE_CONTROL else palette.INACTIVE;
    const boot_end = try drawFitted(&caption, text, frame.CAPTION_SIZE, 0, baseline, strings.COMPLETED_LEGEND, boot_color);
    if (!state.Done) {
        const cancel_x = try drawFitted(&caption, text, frame.CAPTION_SIZE, boot_end, baseline, strings.CONTROL_SEPARATOR, palette.INACTIVE);
        const cancel_color = if (state.CancelReady) palette.ACTIVE_CONTROL else palette.INACTIVE;
        _ = try drawFitted(&caption, text, frame.CAPTION_SIZE, cancel_x, baseline, strings.CANCEL_LEGEND, cancel_color);
    }
    if (state.MenuReady) try paintCountdown(staging, countdownRegion(rectangle), text, baseline, phase.COUNTDOWN_SECONDS);
}

fn captionBaseline(text: Text, height_pixels: u32) !u32 {
    const ascent = try typeset.measure.ascent(text.Face, frame.CAPTION_SIZE);
    const descent = try text.Face.pixelMetric(-@as(i32, text.Face.Descender), frame.CAPTION_SIZE);
    const height: i32 = @intCast(height_pixels);
    if (ascent < 0 or descent < 0 or ascent + descent > height) return error.MetricOutOfRange;
    return @intCast(ascent + @divTrunc(height - ascent - descent, 2));
}

fn countdownRegion(footer: Rect) Rect {
    return .{ .X = footer.X + footer.Width - frame.COUNTDOWN_WIDTH, .Y = footer.Y, .Width = frame.COUNTDOWN_WIDTH, .Height = footer.Height };
}

fn paintCountdown(staging: *Surface, region: Rect, text: Text, baseline: u32, seconds: u8) !void {
    var slot = scoped(staging, region);
    var buffer: [strings.BOOT_COUNTDOWN.len]u8 = undefined;
    const label = try std.fmt.bufPrint(&buffer, strings.BOOT_COUNTDOWN, .{seconds});
    const style: typeset.types.style.TextStyle = .{ .PixelSize = frame.CAPTION_SIZE, .Tracking = 0 };
    const advance = try typeset.measure.advanceWidth(text.Face, style, label);
    const right: i32 = @intCast(slot.Width - frame.INSET);
    if (advance <= 0 or advance > right) return error.MetricOutOfRange;
    graphics.draw.clear(&slot, palette.DESKTOP);
    try graphics.text.drawString(text.Renderer, &slot, text.Face, style, right - advance, @intCast(baseline), label, palette.CAPTION, null);
}

fn subtitleRegion(header: Rect) Rect {
    return .{
        .X = header.X + frame.INSET,
        .Y = header.Y + frame.SUBTITLE_TOP,
        .Width = header.Width - 2 * frame.INSET,
        .Height = header.Height - frame.SUBTITLE_TOP - frame.BORDER,
    };
}

fn subtitle(staging: *Surface, header: Rect, text: Text, state: *const types.model.state.Model) !void {
    var area = scoped(staging, subtitleRegion(header));
    graphics.draw.clear(&area, palette.TITLE_BAR);
    const message = if (state.MenuReady) strings.FINISHED_SUBTITLE else if (state.Done) strings.PHASE_SUBTITLE else strings.SUBTITLE;
    _ = try drawFitted(&area, text, frame.CAPTION_SIZE, 0, frame.SUBTITLE_BASELINE, message, palette.SUBTITLE_TEXT);
}

fn viewport(staging: *Surface, layout: Layout, text: Text, state: *const types.model.state.Model, animation_frame: usize) !void {
    var log = scoped(staging, layout.Log);
    graphics.draw.clear(&log, palette.TERMINAL);
    var content = inset(&log, frame.INSET, frame.INSET);
    for (0..layout.VisibleRows) |index| {
        const entry = model.row(state, index) orelse break;
        var line = scoped(&content, .{ .X = 0, .Y = @as(u32, @intCast(index)) * frame.ROW_HEIGHT, .Width = content.Width, .Height = frame.ROW_HEIGHT });
        try renderRow(&line, text, entry, animation_frame);
    }
}

fn renderRow(line: *Surface, text: Text, entry: types.model.state.Row, animation_frame: usize) !void {
    const status_color = switch (entry.Kind) {
        .Info => palette.INFORMATION,
        .Pass => palette.PASSED,
        .Fail => palette.FAILED,
        .Running => palette.RUNNING,
    };
    const prefix = switch (entry.Kind) {
        .Info => strings.INFO_PREFIX,
        .Pass => strings.PASS_PREFIX,
        .Fail => strings.FAIL_PREFIX,
        .Running => strings.SPINNER[animation_frame % strings.SPINNER.len],
    };
    var pen = try drawFitted(line, text, frame.BODY_SIZE, 0, frame.ROW_BASELINE, prefix, status_color);
    if (entry.Kind != .Info) pen = try drawFitted(line, text, frame.BODY_SIZE, pen, frame.ROW_BASELINE, strings.TEST_PREFIX, palette.INFORMATION);
    if (entry.Verified) |verified| {
        try countedLabel(line, text, entry.Text, pen, strings.VERIFIED_REFUSALS, verified);
    } else if (entry.Repeats > 1) {
        try countedLabel(line, text, entry.Text, pen, strings.REPEATED, entry.Repeats);
    } else {
        _ = try drawFitted(line, text, frame.BODY_SIZE, pen, frame.ROW_BASELINE, entry.Text, palette.INFORMATION);
    }
}

fn countedLabel(line: *Surface, text: Text, name: []const u8, pen: i32, comptime format: []const u8, count: usize) !void {
    var buffer: [@bitSizeOf(usize) + format.len]u8 = undefined;
    const suffix = try std.fmt.bufPrint(&buffer, format, .{count});
    const reserved = @as(u32, @intCast(suffix.len)) * frame.BAR_CELL;
    var label = scoped(line, .{ .X = 0, .Y = 0, .Width = line.Width -| reserved, .Height = line.Height });
    const suffix_start = try drawFitted(&label, text, frame.BODY_SIZE, pen, frame.ROW_BASELINE, name, palette.INFORMATION);
    _ = try drawFitted(line, text, frame.BODY_SIZE, suffix_start, frame.ROW_BASELINE, suffix, palette.INFORMATION);
}

pub fn progressSlots(width: u32) usize {
    return (width -| (frame.PERCENT_WIDTH + 2 * frame.BAR_CELL)) / frame.BAR_CELL;
}

fn progress(staging: *Surface, rectangle: Rect, text: Text, state: *const types.model.state.Model) !void {
    var band = scoped(staging, rectangle);
    graphics.draw.clear(&band, palette.DESKTOP);
    const bar_width = band.Width - frame.PERCENT_WIDTH;
    const filled = model.scaled(state, progressSlots(band.Width));
    for (0..filled) |index| {
        const x = (index + 1) * frame.BAR_CELL + (frame.BAR_CELL - frame.BAR_BLOCK_WIDTH) / 2;
        graphics.draw.fillRect(&band, @intCast(x), frame.BAR_TOP, frame.BAR_BLOCK_WIDTH, frame.BAR_BLOCK_HEIGHT, palette.BAR_FILL);
    }
    _ = try drawFitted(&band, text, frame.BODY_SIZE, 0, frame.ROW_BASELINE, strings.BAR_START, palette.CAPTION);
    _ = try drawFitted(&band, text, frame.BODY_SIZE, @intCast(bar_width - frame.BAR_CELL), frame.ROW_BASELINE, strings.BAR_END, palette.CAPTION);
    var caption: [frame.PERCENT_CELLS]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&caption, strings.PERCENT, .{model.percent(state)});
    for (formatted, 0..) |byte, index| {
        if (byte == ' ') continue;
        const x = bar_width + index * frame.BAR_CELL;
        _ = try drawFitted(&band, text, frame.BODY_SIZE, @intCast(x), frame.ROW_BASELINE, formatted[index..][0..1], palette.CAPTION);
    }
}

fn drawFitted(surface: *Surface, text: Text, size: i32, x: i32, baseline: u32, value: []const u8, color: Color) !i32 {
    if (x >= surface.Width) return x;
    const style: typeset.types.style.TextStyle = .{ .PixelSize = size, .Tracking = 0 };
    var cursor = try typeset.types.cursor.Cursor.initialize(text.Face, style, value, x);
    const limit = @as(i64, surface.Width) * limits.ONE_PIXEL;
    const byte_budget = @min(value.len, @as(usize, surface.Width) * 4);
    var fitted: usize = 0;
    var end = cursor.PenX;
    while (cursor.Offset < byte_budget) {
        _ = (try cursor.next()) orelse break;
        if (cursor.Offset > byte_budget or cursor.PenX > limit) break;
        fitted = cursor.Offset;
        end = cursor.PenX;
    }
    try graphics.text.drawString(text.Renderer, surface, text.Face, style, x, @intCast(baseline), value[0..fitted], color, null);
    return @divFloor(end, limits.ONE_PIXEL);
}

fn panel(surface: *Surface, rectangle: Rect, color: Color) Surface {
    var result = scoped(surface, rectangle);
    graphics.draw.clear(&result, palette.BORDER);
    var interior = inset(&result, frame.BORDER, frame.BORDER);
    graphics.draw.clear(&interior, color);
    return result;
}

fn inset(surface: *Surface, horizontal: u32, vertical: u32) Surface {
    return scoped(surface, .{ .X = horizontal, .Y = vertical, .Width = surface.Width - 2 * horizontal, .Height = surface.Height - 2 * vertical });
}

fn scoped(surface: *const Surface, rectangle: Rect) Surface {
    return .{
        .Base = surface.Base + surface.offset(rectangle.X, rectangle.Y),
        .Width = rectangle.Width,
        .Height = rectangle.Height,
        .Stride = surface.Stride,
        .Format = surface.Format,
    };
}

fn commit(target: *Surface, staging: *const Surface, rectangle: Rect) void {
    var y = rectangle.Y;
    while (y < rectangle.Y + rectangle.Height) : (y += 1) {
        const source = staging.offset(rectangle.X, y);
        const destination = target.offset(rectangle.X, y);
        @memcpy(target.Base[destination..][0..rectangle.Width], staging.Base[source..][0..rectangle.Width]);
    }
}
