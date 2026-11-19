//! Settle Planned Diagnostic Work Against Verified Outcomes

const std = @import("std");

const firmware = @import("tests").constants.firmware;
const limits = @import("tests").phase.constants.work;
const Scenario = @import("tests").types.scenario.Scenario;
const Work = @import("tests").phase.types.work.Work;

pub fn reference() u32 {
    var total: u32 = 0;
    for (std.enums.values(Scenario)) |selected| total += budget(selected);
    return total;
}

pub fn settle(tally: *Work, selected: Scenario, count: u32) void {
    tally.Planned = (tally.Planned -| budget(selected)) +| count;
    tally.credit(count);
}

pub fn retain(tally: *Work, selected: Scenario, count: u32) void {
    // Leave unverified work in the plan, even if the estimate was exhausted.
    tally.addPlan((count +| 1) -| budget(selected));
    tally.credit(count);
}

fn budget(selected: Scenario) u32 {
    return switch (selected) {
        .Standard => limits.STANDARD_ESTIMATE,
        .Firmware => firmware.ASSERTION_COUNT,
        .Devices => limits.DEVICE_CHECKS,
        .PulseDeath, .Collapse => limits.TERMINAL_CHECKS,
    };
}
