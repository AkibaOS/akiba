//! Diagnostic Screen Progress Model Regressions

const std = @import("std");

const labels = @import("tests").strings.screen;
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

pub fn metadata() !void {
    const date = project.screen.date;
    var buffer: [project.screen.constants.frame.DATE_BYTES]u8 = undefined;
    const leap_day_seconds: i128 = 1_709_164_800;
    const formatted = date.format(&buffer, leap_day_seconds * std.time.ns_per_s).?;
    try std.testing.expectEqualStrings(labels.LEAP_BUILD_DATE, formatted);
    try std.testing.expect(date.valid(formatted));
    try std.testing.expect(!date.valid(labels.INVALID_BUILD_DATE));
    try std.testing.expect(!date.valid(labels.DASHED_BUILD_DATE));
    try std.testing.expect(!date.valid(labels.INVALID_CALENDAR_DATE));
    try std.testing.expect(date.format(&buffer, -1) == null);
}
