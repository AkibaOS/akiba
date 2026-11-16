//! Splash Trail State Regressions

const std = @import("std");

const splash = @import("shared").splash;
const strings = @import("tests").strings.render;

const SplashState = splash.types.state.SplashState;

pub fn boundedTrailAndProgress() !void {
    var state = SplashState.initialize(2);
    try std.testing.expect(!state.isActive() and !state.hasFailed());
    try std.testing.expectEqual(@as(u8, 0), state.ProgressStep);
    for (0..splash.constants.limits.TRAIL_LINES) |index| try std.testing.expectEqual(@as(usize, 0), state.line(index).len);
    state.pushMessage(strings.LETTER);
    try std.testing.expectEqual(@as(u8, 1), state.ProgressStep);
    try std.testing.expectEqualStrings(strings.LETTER, state.line(2));
    state.pushMessage(strings.SECOND_LETTER);
    state.pushMessage(strings.LONG_MESSAGE);
    try std.testing.expectEqual(@as(u8, 2), state.ProgressStep);
    try std.testing.expectEqualStrings(strings.LETTER, state.line(0));
    try std.testing.expectEqualStrings(strings.SECOND_LETTER, state.line(1));
    try std.testing.expectEqual(splash.constants.limits.MESSAGE_CAPACITY, state.line(2).len);
    try std.testing.expectEqualStrings(strings.LONG_MESSAGE[0..splash.constants.limits.MESSAGE_CAPACITY], state.line(2));
    state.pushMessage(strings.EMPTY);
    try std.testing.expectEqualStrings(strings.SECOND_LETTER, state.line(0));
    try std.testing.expectEqualStrings(strings.LONG_MESSAGE[0..splash.constants.limits.MESSAGE_CAPACITY], state.line(1));
    try std.testing.expectEqual(@as(usize, 0), state.line(2).len);
    try std.testing.expectEqual(@as(u8, 2), state.ProgressStep);
    state.Active = 2;
    state.Failed = 3;
    try std.testing.expect(state.isActive() and state.hasFailed());
    state = SplashState.initialize(0);
    state.pushMessage(strings.LETTER);
    try std.testing.expectEqual(@as(u8, 0), state.ProgressStep);
}
