//! Guest Serial Result Validation

const std = @import("std");

const firmware = @import("tests").strings.firmware;
const guest = @import("tests").strings.guest;
const labels = @import("tests").strings.scenario;
const progress = @import("tests").phase.constants.live;
const strings = @import("tests").strings.runner;
const tables = @import("tests").strings.tables;
const Scenario = @import("tests").types.scenario.Scenario;
const Work = @import("tests").phase.types.work.Work;

pub fn failedBeforeSelection(bytes: []const u8) bool {
    return std.mem.indexOf(u8, bytes, strings.CHECK_FAIL) != null or
        std.mem.indexOf(u8, bytes, strings.KERNEL_PANIC) != null or
        std.mem.indexOf(u8, bytes, labels.COLLAPSE_BANNER) != null;
}

pub fn cancelledCount(bytes: []const u8) !usize {
    if (failedBeforeSelection(bytes) or std.mem.indexOf(u8, bytes, strings.CHECK_COMPLETE) != null or
        std.mem.indexOf(u8, bytes, firmware.COMPLETE) != null or std.mem.indexOf(u8, bytes, strings.READY) != null) return error.InvalidCancellationEvidence;
    var count: ?usize = null;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, strings.CHECK_CANCELLED)) continue;
        if (count != null or lines.index == null) return error.InvalidCancellationEvidence;
        const text = std.mem.trimEnd(u8, line[strings.CHECK_CANCELLED.len..], strings.CARRIAGE_RETURN);
        count = std.fmt.parseInt(usize, text, 10) catch return error.InvalidCancellationEvidence;
    }
    if (count == null or std.mem.count(u8, bytes, strings.CHECK_PASS) != count.?) return error.InvalidCancellationEvidence;
    return count.?;
}

pub fn ordinaryReady(bytes: []const u8) !bool {
    if (failedBeforeSelection(bytes)) return error.NormalBootFailed;
    if (std.mem.indexOf(u8, bytes, strings.CHECK_BEGIN) != null or
        std.mem.indexOf(u8, bytes, firmware.BEGIN) != null or
        std.mem.indexOf(u8, bytes, strings.CHECK_COMPLETE) != null or
        std.mem.indexOf(u8, bytes, strings.CHECK_CANCELLED) != null or
        std.mem.indexOf(u8, bytes, firmware.COMPLETE) != null or
        std.mem.indexOf(u8, bytes, strings.CHECK_PASS) != null) return error.UnexpectedDiagnosticBoot;
    return try uniqueLine(bytes, strings.READY) != null;
}

pub fn evaluate(bytes: []const u8, scenario: Scenario) !?usize {
    if (std.mem.indexOf(u8, bytes, strings.CHECK_FAIL) != null) return error.GuestCheckFailed;
    if (scenario == .PulseDeath) return expectedFatal(bytes);
    if (scenario == .Collapse) return expectedCollapse(bytes);
    if (std.mem.indexOf(u8, bytes, strings.KERNEL_PANIC) != null or
        std.mem.indexOf(u8, bytes, labels.COLLAPSE_BANNER) != null) return error.GuestCheckFailed;
    if (scenario == .Firmware) return firmwareResult(bytes);
    if (std.mem.indexOf(u8, bytes, strings.READY) == null) return null;
    if (std.mem.indexOf(u8, bytes, strings.CHECK_BEGIN) == null) return error.MissingGuestChecks;
    const marker = std.mem.indexOf(u8, bytes, strings.CHECK_COMPLETE) orelse return error.IncompleteGuestChecks;
    const number = bytes[marker + strings.CHECK_COMPLETE.len ..];
    const end = std.mem.indexOfAny(u8, number, strings.LINE_SEPARATORS) orelse return error.IncompleteGuestChecks;
    const passed = std.fmt.parseInt(usize, number[0..end], 10) catch return error.InvalidGuestCheckCount;
    if (passed == 0 or std.mem.count(u8, bytes, strings.CHECK_PASS) != passed) return error.IncompleteGuestChecks;
    return passed;
}

pub fn verifyBootstrap(bytes: []const u8, scenario: Scenario) !void {
    const began = uniqueLine(bytes, tables.ROLLBACK_BEGIN) catch return error.InvalidBootstrapEvidence;
    const ended = uniqueLine(bytes, tables.ROLLBACK_COMPLETE) catch return error.InvalidBootstrapEvidence;
    if (scenario != .Standard) {
        if (began != null or ended != null) return error.UnexpectedBootstrapSweep;
        return;
    }
    const begin = began orelse return error.InvalidBootstrapEvidence;
    const complete = ended orelse return error.InvalidBootstrapEvidence;
    const checks = (uniqueLine(bytes, strings.CHECK_BEGIN) catch return error.InvalidBootstrapEvidence) orelse return error.InvalidBootstrapEvidence;
    if (begin >= complete or complete >= checks) return error.InvalidBootstrapEvidence;
}

pub fn rollbackWork(bytes: []const u8) !Work {
    var tally: Work = .{ .Planned = 0 };
    var began = false;
    var matched = false;
    var checks_started = false;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        if (lines.index == null) break;
        const line = std.mem.trimEnd(u8, raw, strings.CARRIAGE_RETURN);
        if (std.mem.eql(u8, line, std.mem.trimEnd(u8, tables.ROLLBACK_BEGIN, strings.LINE_SEPARATORS))) {
            if (began or checks_started) return error.InvalidBootstrapEvidence;
            began = true;
        } else if (std.mem.startsWith(u8, line, tables.ROLLBACK_SCHEDULE_PREFIX)) {
            if (!began or tally.Planned != 0 or checks_started) return error.InvalidBootstrapEvidence;
            tally.Planned = try rollbackCount(line[tables.ROLLBACK_SCHEDULE_PREFIX.len..]);
        } else if (std.mem.startsWith(u8, line, tables.ROLLBACK_VERIFIED_PREFIX)) {
            if (matched or tally.Planned == 0 or checks_started) return error.InvalidBootstrapEvidence;
            if (try rollbackCount(line[tables.ROLLBACK_VERIFIED_PREFIX.len..]) != tally.Planned) return error.InvalidBootstrapEvidence;
            matched = true;
        } else if (std.mem.eql(u8, line, std.mem.trimEnd(u8, tables.ROLLBACK_COMPLETE, strings.LINE_SEPARATORS))) {
            if (!matched or tally.Verified != 0 or checks_started) return error.InvalidBootstrapEvidence;
            tally.Verified = tally.Planned;
        } else if (std.mem.eql(u8, line, strings.CHECK_BEGIN)) {
            if (tally.Verified == 0 or checks_started) return error.InvalidBootstrapEvidence;
            checks_started = true;
        }
    }
    return tally;
}

fn rollbackCount(text: []const u8) !u32 {
    if (text.len == 0) return error.InvalidBootstrapEvidence;
    for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidBootstrapEvidence;
    const count = std.fmt.parseInt(u32, text, 10) catch return error.InvalidBootstrapEvidence;
    if (count == 0) return error.InvalidBootstrapEvidence;
    return count;
}

pub fn partialChecks(bytes: []const u8, selected: Scenario) u32 {
    const begin = switch (selected) {
        .Standard, .Devices => strings.CHECK_BEGIN,
        .Firmware => std.mem.trimEnd(u8, firmware.BEGIN, strings.LINE_SEPARATORS),
        .PulseDeath, .Collapse => return 0,
    };
    var count: u32 = 0;
    var began = false;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        if (lines.index == null) break;
        const line = std.mem.trimEnd(u8, raw, strings.CARRIAGE_RETURN);
        if (failedBeforeSelection(line) or std.mem.startsWith(u8, line, strings.CHECK_COMPLETE) or
            std.mem.startsWith(u8, line, firmware.COMPLETE)) break;
        if (std.mem.eql(u8, line, begin)) {
            if (began) return 0;
            began = true;
        } else if (began and line.len > strings.CHECK_PASS.len and std.mem.startsWith(u8, line, strings.CHECK_PASS)) {
            count += 1;
        }
    }
    return count;
}

pub fn verifyDisplay(bytes: []const u8) !void {
    const displayed = (uniqueLine(bytes, guest.DISPLAY_READY) catch return error.InvalidDiagnosticDisplay) orelse return error.InvalidDiagnosticDisplay;
    const begun = (uniqueLine(bytes, strings.CHECK_BEGIN) catch return error.InvalidDiagnosticDisplay) orelse return error.InvalidDiagnosticDisplay;
    if (displayed >= begun) return error.InvalidDiagnosticDisplay;
}

pub fn standardProgress(bytes: []const u8) !u16 {
    var rollback_started = false;
    var rollback_complete = false;
    var checks_started = false;
    var groups: u16 = 0;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        if (lines.index == null) break;
        const line = std.mem.trimEnd(u8, raw, strings.CARRIAGE_RETURN);
        if (std.mem.eql(u8, line, std.mem.trimEnd(u8, tables.ROLLBACK_BEGIN, strings.LINE_SEPARATORS))) {
            if (rollback_started or checks_started) return error.InvalidBootstrapEvidence;
            rollback_started = true;
        } else if (std.mem.eql(u8, line, std.mem.trimEnd(u8, tables.ROLLBACK_COMPLETE, strings.LINE_SEPARATORS))) {
            if (!rollback_started or rollback_complete or checks_started) return error.InvalidBootstrapEvidence;
            rollback_complete = true;
        } else if (std.mem.eql(u8, line, strings.CHECK_BEGIN)) {
            if (!rollback_complete or checks_started) return error.InvalidBootstrapEvidence;
            checks_started = true;
        } else if (std.mem.startsWith(u8, line, tables.STANDARD_GROUP_PREFIX)) {
            const number = std.fmt.parseInt(u16, line[tables.STANDARD_GROUP_PREFIX.len..], 10) catch return error.InvalidBootstrapEvidence;
            if (!checks_started or groups + 1 >= progress.STANDARD_UNITS or number != groups + 1) return error.InvalidBootstrapEvidence;
            groups += 1;
        }
    }
    return groups + @intFromBool(rollback_complete);
}

fn firmwareResult(bytes: []const u8) !?usize {
    if (std.mem.indexOf(u8, bytes, strings.READY) != null or
        std.mem.indexOf(u8, bytes, strings.CHECK_COMPLETE) != null) return error.UnexpectedFirmwareOutcome;
    const marker = std.mem.indexOf(u8, bytes, firmware.COMPLETE) orelse return null;
    const begin = try uniqueLine(bytes, firmware.BEGIN) orelse return error.MissingGuestChecks;
    if (begin >= marker or std.mem.count(u8, bytes, firmware.COMPLETE) != 1) return error.IncompleteGuestChecks;
    const number = bytes[marker + firmware.COMPLETE.len ..];
    const end = std.mem.indexOfAny(u8, number, strings.LINE_SEPARATORS) orelse return null;
    const passed = std.fmt.parseInt(usize, number[0..end], 10) catch return error.InvalidGuestCheckCount;
    if (passed == 0 or std.mem.count(u8, bytes, strings.CHECK_PASS) != passed) return error.IncompleteGuestChecks;
    return passed;
}

fn expectedCollapse(bytes: []const u8) !?usize {
    if (std.mem.indexOf(u8, bytes, strings.KERNEL_PANIC) != null or
        std.mem.indexOf(u8, bytes, strings.READY) != null or
        std.mem.indexOf(u8, bytes, strings.CHECK_COMPLETE) != null) return error.UnexpectedFatalOutcome;
    const halted = try uniqueLine(bytes, labels.COLLAPSE_HALT) orelse return null;
    const begin = try uniqueLine(bytes, strings.CHECK_BEGIN) orelse return error.UnexpectedFatalOutcome;
    const checkpoint = try uniqueLine(bytes, labels.COLLAPSE_CHECKPOINT) orelse return error.UnexpectedFatalOutcome;
    const banner = std.mem.indexOf(u8, bytes, labels.COLLAPSE_BANNER) orelse return error.UnexpectedFatalOutcome;
    const reason = try uniqueLine(bytes, labels.COLLAPSE_REASON) orelse return error.UnexpectedFatalOutcome;
    if (begin >= checkpoint or checkpoint >= banner or banner >= reason or reason >= halted or
        std.mem.count(u8, bytes, labels.COLLAPSE_BANNER) != 1) return error.UnexpectedFatalOutcome;
    return 1;
}

fn expectedFatal(bytes: []const u8) !?usize {
    if (std.mem.indexOf(u8, bytes, labels.COLLAPSE_BANNER) != null) return error.UnexpectedFatalOutcome;
    if (std.mem.indexOf(u8, bytes, strings.READY) != null or
        std.mem.indexOf(u8, bytes, strings.CHECK_COMPLETE) != null) return error.UnexpectedFatalOutcome;
    const panic = std.mem.indexOf(u8, bytes, strings.KERNEL_PANIC) orelse return null;
    const tail = bytes[panic..];
    const end = std.mem.indexOfAny(u8, tail, strings.LINE_SEPARATORS) orelse return null;
    const expected = std.mem.trimEnd(u8, labels.PANIC, strings.LINE_SEPARATORS);
    if (!std.mem.eql(u8, tail[0..end], expected) or
        std.mem.count(u8, bytes, strings.KERNEL_PANIC) != 1) return error.UnexpectedFatalOutcome;
    const begin = try uniqueLine(bytes, strings.CHECK_BEGIN) orelse return error.UnexpectedFatalOutcome;
    const checkpoint = try uniqueLine(bytes, labels.CHECKPOINT) orelse return error.UnexpectedFatalOutcome;
    const exact_panic = try uniqueLine(bytes, labels.PANIC) orelse return error.UnexpectedFatalOutcome;
    if (begin >= checkpoint or checkpoint >= panic or exact_panic != panic) return error.UnexpectedFatalOutcome;
    return 1;
}

fn uniqueLine(bytes: []const u8, expected: []const u8) !?usize {
    const text = std.mem.trimEnd(u8, expected, strings.LINE_SEPARATORS);
    var found: ?usize = null;
    var lines = std.mem.tokenizeAny(u8, bytes, strings.LINE_SEPARATORS);
    while (lines.next()) |line| {
        if (!std.mem.eql(u8, line, text)) continue;
        if (found != null) return error.UnexpectedFatalOutcome;
        found = @intFromPtr(line.ptr) - @intFromPtr(bytes.ptr);
    }
    return found;
}
