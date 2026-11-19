//! Diagnostic Screen Progress Model Regressions

const std = @import("std");

const labels = @import("tests").fast.strings.screen;
const project = @import("tests");

pub fn lifecycle() !void {
    const model = project.screen.model;
    var rows: [6]project.screen.types.model.Row = undefined;
    var state = model.initialize(&rows, 2);
    try std.testing.expectEqual(@as(usize, 0), model.percent(&state));
    try std.testing.expectEqual(.Info, model.row(&state, 0).?.Kind);
    try std.testing.expect(!model.finish(&state, .Pass));
    try std.testing.expect(model.begin(&state, labels.FIRST_CASE));
    try std.testing.expect(!model.begin(&state, labels.NEXT_CASE));
    try std.testing.expect(!model.complete(&state));
    const running = model.row(&state, 1).?;
    try std.testing.expectEqual(.Running, running.Kind);
    try std.testing.expectEqualStrings(labels.FIRST_CASE, running.Text);
    try std.testing.expectEqual(@as(usize, 0), model.percent(&state));
    try std.testing.expect(model.finish(&state, .Pass));
    try std.testing.expectEqual(.Pass, model.row(&state, 1).?.Kind);
    try std.testing.expectEqual(@as(usize, 50), model.percent(&state));
    try std.testing.expect(model.begin(&state, labels.NEXT_CASE));
    try std.testing.expect(model.finish(&state, .Fail));
    try std.testing.expectEqual(.Fail, model.row(&state, 2).?.Kind);
    try std.testing.expectEqual(@as(usize, 1), state.Failed);
    try std.testing.expectEqual(@as(usize, 100), model.percent(&state));
    try std.testing.expect(model.complete(&state));
    try std.testing.expectEqual(.Info, model.row(&state, 3).?.Kind);
    try std.testing.expect(model.row(&state, 4) == null);
    try std.testing.expect(!model.complete(&state));
    try std.testing.expect(!model.begin(&state, labels.FINAL_CASE));
}

pub fn scrolling() !void {
    const model = project.screen.model;
    var rows: [3]project.screen.types.model.Row = undefined;
    const case_count = 129;
    var state = model.initialize(&rows, case_count);
    try std.testing.expect(model.begin(&state, labels.FIRST_CASE));
    try std.testing.expect(model.finish(&state, .Pass));
    for (1..case_count - 1) |_| {
        try std.testing.expect(model.begin(&state, labels.NEXT_CASE));
        try std.testing.expect(model.finish(&state, .Pass));
    }
    try std.testing.expect(model.begin(&state, labels.FINAL_CASE));
    try std.testing.expectEqualStrings(labels.NEXT_CASE, model.row(&state, 0).?.Text);
    try std.testing.expectEqualStrings(labels.NEXT_CASE, model.row(&state, 1).?.Text);
    try std.testing.expectEqual(.Running, model.row(&state, 2).?.Kind);
    try std.testing.expectEqualStrings(labels.FINAL_CASE, model.row(&state, 2).?.Text);
    try std.testing.expect(model.row(&state, 3) == null);
    try std.testing.expectEqual(@as(usize, 99), model.percent(&state));
    try std.testing.expect(model.finish(&state, .Pass));
    try std.testing.expect(model.complete(&state));
    try std.testing.expectEqualStrings(labels.NEXT_CASE, model.row(&state, 0).?.Text);
    try std.testing.expectEqualStrings(labels.FINAL_CASE, model.row(&state, 1).?.Text);
    try std.testing.expectEqual(.Info, model.row(&state, 2).?.Kind);
    try std.testing.expectEqual(@as(usize, case_count), state.Completed);
}

pub fn evidence() !void {
    const model = project.screen.model;
    var rows: [5]project.screen.types.model.Row = undefined;
    var state = model.initialize(&rows, 2);
    try std.testing.expect(model.begin(&state, labels.FIRST_CASE));
    const repeats = 32;
    for (0..repeats) |_| model.evidence(&state, .Pass, labels.NEXT_CASE);
    try std.testing.expectEqual(.Pass, model.row(&state, 1).?.Kind);
    try std.testing.expectEqualStrings(labels.NEXT_CASE, model.row(&state, 1).?.Text);
    try std.testing.expectEqual(@as(usize, repeats), model.row(&state, 1).?.Repeats);
    try std.testing.expectEqual(.Running, model.row(&state, 2).?.Kind);
    model.evidence(&state, .Fail, labels.NEXT_CASE);
    try std.testing.expectEqual(.Fail, model.row(&state, 2).?.Kind);
    try std.testing.expectEqual(.Running, model.row(&state, 3).?.Kind);
    try std.testing.expectEqual(@as(usize, 0), model.percent(&state));
    try std.testing.expect(model.finish(&state, .Pass));
    try std.testing.expectEqual(@as(usize, 50), model.percent(&state));
}

pub fn failure() !void {
    const model = project.screen.model;
    var rows: [1]project.screen.types.model.Row = undefined;
    var state = model.initialize(&rows, 2);
    try std.testing.expect(model.begin(&state, labels.FIRST_CASE));
    try std.testing.expect(model.fail(&state, labels.NEXT_CASE));
    const latest = model.row(&state, 0).?;
    try std.testing.expectEqual(.Fail, latest.Kind);
    try std.testing.expectEqualStrings(labels.NEXT_CASE, latest.Text);
    try std.testing.expectEqual(@as(usize, 50), model.percent(&state));
    try std.testing.expect(!model.complete(&state));
}

pub fn checkpoints() !void {
    const model = project.screen.model;
    var rows: [6]project.screen.types.model.Row = undefined;
    var state = model.initialize(&rows, 2);
    try std.testing.expect(!model.checkpoint(&state, 1));
    try std.testing.expect(model.begin(&state, labels.FIRST_CASE));
    try std.testing.expect(model.checkpoint(&state, 32));
    try std.testing.expect(!model.checkpoint(&state, 32));
    try std.testing.expect(!model.checkpoint(&state, 31));
    try std.testing.expect(model.checkpoint(&state, 64));
    const running = model.row(&state, 1).?;
    try std.testing.expectEqual(.Running, running.Kind);
    try std.testing.expectEqual(@as(?usize, 64), running.Verified);
    try std.testing.expect(model.row(&state, 2) == null);
    try std.testing.expectEqual(@as(usize, 0), model.percent(&state));
    try std.testing.expect(model.finish(&state, .Pass));
    try std.testing.expectEqual(@as(?usize, 64), model.row(&state, 1).?.Verified);
    try std.testing.expectEqual(@as(usize, 50), model.percent(&state));
    try std.testing.expect(model.begin(&state, labels.NEXT_CASE));
    try std.testing.expectEqual(@as(?usize, null), model.row(&state, 2).?.Verified);
}

pub fn measuredWork() !void {
    const model = project.screen.model;
    var rows: [4]project.screen.types.model.Row = undefined;
    var state = model.initialize(&rows, 2);
    try std.testing.expect(!model.beginWork(&state, 4));
    try std.testing.expect(model.begin(&state, labels.FIRST_CASE));
    try std.testing.expect(!model.beginWork(&state, 0));
    try std.testing.expect(model.beginWork(&state, 4));
    try std.testing.expect(!model.finish(&state, .Pass));
    try std.testing.expect(!model.checkpoint(&state, 2));
    const expected_percent = [_]usize{ 12, 25, 37, 49 };
    const expected_cells = [_]usize{ 3, 6, 9, 11 };
    for (expected_percent, expected_cells, 1..) |percent, cells, verified| {
        try std.testing.expect(model.checkpoint(&state, verified));
        try std.testing.expectEqual(@as(?usize, verified), model.row(&state, 1).?.Verified);
        try std.testing.expectEqual(percent, model.percent(&state));
        try std.testing.expectEqual(cells, model.scaled(&state, 24));
        try std.testing.expectEqual(@as(usize, 0), state.Completed);
    }
    try std.testing.expect(!model.checkpoint(&state, 5));
    try std.testing.expect(model.finish(&state, .Pass));
    try std.testing.expectEqual(@as(usize, 50), model.percent(&state));
    try std.testing.expectEqual(@as(?usize, null), state.ActiveTotal);
}

pub fn verificationWeight() !void {
    const model = project.screen.model;
    var rows: [4]project.screen.types.model.Row = undefined;
    var state = model.initialize(&rows, 28);
    state.Work = .{ .Planned = 1910, .Verified = 0 };
    try std.testing.expect(model.begin(&state, labels.FIRST_CASE));
    try std.testing.expect(model.beginWork(&state, 820));
    for (1..821) |count| try std.testing.expect(model.checkpoint(&state, count));
    try std.testing.expectEqual(@as(usize, 30), model.percent(&state));
    try std.testing.expectEqual(@as(u32, 2730), state.Work.?.Planned);
    try std.testing.expectEqual(@as(u32, 820), state.Work.?.Verified);
    try std.testing.expect(model.finish(&state, .Pass));
    try std.testing.expectEqual(@as(u32, 820), state.Work.?.Verified);
    try std.testing.expect(model.begin(&state, labels.NEXT_CASE));
    model.evidence(&state, .Pass, labels.FIRST_CASE);
    model.evidence(&state, .Pass, labels.FIRST_CASE);
    try std.testing.expectEqual(@as(u32, 822), state.Work.?.Verified);
    state.Work = .{ .Planned = 2730, .Verified = 2730 };
    try std.testing.expectEqual(@as(usize, 99), model.percent(&state));
    state.MenuReady = true;
    try std.testing.expectEqual(@as(usize, 100), model.percent(&state));
}

pub fn rollbackClock() !void {
    const clock = project.screen.clock;
    const origin: u32 = 0xfffff0;
    const period: u32 = 429_545;
    var state = clock.start(origin);
    try std.testing.expect(!clock.sample(&state, (origin + period - 1) & 0xffffff));
    try std.testing.expectEqual(@as(usize, 0), state.Frame);
    try std.testing.expect(clock.sample(&state, (origin + period) & 0xffffff));
    try std.testing.expectEqual(@as(usize, 1), state.Frame);
    try std.testing.expect(clock.sample(&state, (origin + 3 * period + 17) & 0xffffff));
    try std.testing.expectEqual(@as(usize, 3), state.Frame);
    try std.testing.expect(!clock.sample(&state, (origin + 4 * period - 1) & 0xffffff));
    try std.testing.expect(clock.sample(&state, (origin + 4 * period) & 0xffffff));
    try std.testing.expectEqual(@as(usize, 4), state.Frame);
    try std.testing.expect(clock.sample(&state, (origin + 8 * period) & 0xffffff));
    try std.testing.expectEqual(@as(usize, 0), state.Frame);
}

pub fn metadata() !void {
    const date = project.phase.date;
    var buffer: [project.phase.constants.date.DATE_BYTES]u8 = undefined;
    const leap_day_seconds: i128 = 1_709_164_800;
    const formatted = date.format(&buffer, leap_day_seconds * std.time.ns_per_s).?;
    try std.testing.expectEqualStrings(labels.LEAP_BUILD_DATE, formatted);
    try std.testing.expect(date.valid(formatted));
    try std.testing.expect(!date.valid(labels.INVALID_BUILD_DATE));
    try std.testing.expect(!date.valid(labels.DASHED_BUILD_DATE));
    try std.testing.expect(!date.valid(labels.INVALID_CALENDAR_DATE));
    try std.testing.expect(date.format(&buffer, -1) == null);
}
