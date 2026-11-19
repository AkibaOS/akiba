//! Restore Verified Results In A Fresh Diagnostic View

const std = @import("std");

const live = @import("tests").phase.live;
const limits = @import("tests").phase.constants.live;
const menu = @import("tests").phase.menu;
const model = @import("tests").screen.model;
const runner = @import("tests").strings.runner;
const schedule = @import("tests").screen.strings.schedule;
const text = @import("tests").screen.strings.text;
const types = @import("tests").screen.types.model;
const Offer = @import("tests").phase.types.live.Offer;
const Scenario = @import("tests").types.scenario.Scenario;

comptime {
    std.debug.assert(text.PHASE_NAMES.len == std.enums.values(Scenario).len);
}

pub fn name(selected: Scenario) []const u8 {
    return text.PHASE_NAMES[@intFromEnum(selected)];
}

pub fn incompleteName(selected: Scenario) []const u8 {
    return text.INCOMPLETE_PHASES[@intFromEnum(selected)];
}

pub fn initialize(rows: []types.Row, offer: Offer) types.Model {
    var state = model.initialize(rows, limits.TOTAL_UNITS);
    const previous = live.preceding(offer.Ticket.Scenario);
    state.Completed = live.completed(previous, offer.StandardCompleted, offer.InterruptedMask);
    state.Failed = @popCount(offer.FailedMask);
    state.Work = offer.Work;
    for (std.enums.values(Scenario)) |selected| {
        const bit = menu.phaseBit(selected);
        if (previous & bit == 0) break;
        if (selected == .Standard) recallStandard(&state, offer, bit);
        if (offer.InterruptedMask & bit != 0) {
            model.recall(&state, .{ .Kind = .Fail, .Text = incompleteName(selected) });
        } else {
            model.recall(&state, .{ .Kind = if (offer.FailedMask & bit != 0) .Fail else .Pass, .Text = name(selected) });
        }
    }
    return state;
}

fn recallStandard(state: *types.Model, offer: Offer, bit: u8) void {
    const units = @min(offer.StandardCompleted, limits.STANDARD_UNITS);
    const completed_failure = offer.FailedMask & bit != 0 and offer.InterruptedMask & bit == 0;
    for (0..units) |index| {
        const kind: types.Kind = if (completed_failure and index + 1 == units) .Fail else .Pass;
        const label = if (index == 0) text.BOOTSTRAP_ROLLBACK else standardName(index - 1);
        model.recall(state, .{ .Kind = kind, .Text = label });
    }
}

fn standardName(index: usize) []const u8 {
    const group = schedule.GROUPS[index];
    return std.mem.trimEnd(u8, group[runner.GROUP_PREFIX.len..], runner.LINE_SEPARATORS);
}
