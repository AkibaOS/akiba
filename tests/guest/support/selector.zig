//! Test Phase Selection And Display Metadata

const std = @import("std");

const config = @import("tests").phase.config;
const date = @import("tests").screen.date;
const inputs = @import("tests").constants.scenario;
const labels = @import("tests").strings.scenario;
const phase = @import("tests").guest.support.phase;
const Scenario = @import("tests").types.scenario.Scenario;

var choice: ?Scenario = null;

pub fn selectEarly() Scenario {
    const scenario = choose();
    choice = scenario;
    return scenario;
}

pub fn selected() Scenario {
    return choice orelse @panic(labels.INVALID_PHASE);
}

fn choose() Scenario {
    if (config.liveEnabled()) return phase.selectLive() orelse @panic(labels.INVALID_PHASE);
    var value: [inputs.MAX_VALUE_BYTES]u8 = undefined;
    if (config.readValue(labels.PHASE_FILE, &value, true)) |flag| {
        if (!std.mem.eql(u8, flag, labels.PHASE_VALUE)) @panic(labels.INVALID_PHASE);
        return phase.select() orelse @panic(labels.INVALID_PHASE);
    }
    const text = config.readValue(labels.FILE, &value, true) orelse return .Standard;
    return std.meta.stringToEnum(Scenario, text) orelse @panic(labels.INVALID);
}

pub fn allowCancellation() bool {
    var value: [inputs.MAX_VALUE_BYTES]u8 = undefined;
    const flag = config.readValue(labels.CANCEL_FILE, &value, false) orelse return false;
    return std.mem.eql(u8, flag, labels.PHASE_VALUE);
}

pub fn buildDate(destination: []u8) ?[]const u8 {
    const value = config.readValue(labels.BUILD_DATE_FILE, destination, false) orelse return null;
    return if (date.valid(value)) value else null;
}
