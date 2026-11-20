//! Rollback Frames From An Independent Wrapping Timer

const limits = @import("tests").screen.constants.clock.timer;
const strings = @import("tests").screen.strings.text;
const Clock = @import("tests").screen.types.clock.timer.Clock;

pub fn start(counter: u32) Clock {
    return .{ .Last = counter & limits.COUNTER_MASK };
}

pub fn sample(clock: *Clock, counter: u32) bool {
    const current = counter & limits.COUNTER_MASK;
    const elapsed = (current -% clock.Last) & limits.COUNTER_MASK;
    clock.Last = current;
    const ticks = clock.Remainder + elapsed;
    clock.Remainder = ticks % limits.FRAME_TICKS;
    const frame = (clock.Frame + ticks / limits.FRAME_TICKS) % strings.SPINNER.len;
    if (clock.Frame == frame) return false;
    clock.Frame = frame;
    return true;
}
