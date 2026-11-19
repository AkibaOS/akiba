//! Guest Serial Result Validation

const std = @import("std");

const firmware = @import("tests").strings.firmware;
const labels = @import("tests").strings.scenario;
const strings = @import("tests").strings.runner;
const tables = @import("tests").strings.tables;
const Scenario = @import("tests").types.scenario.Scenario;

pub fn failedBeforeSelection(bytes: []const u8) bool {
    return std.mem.indexOf(u8, bytes, strings.CHECK_FAIL) != null or
        std.mem.indexOf(u8, bytes, strings.KERNEL_PANIC) != null or
        std.mem.indexOf(u8, bytes, labels.COLLAPSE_BANNER) != null;
}

pub fn cancelledCount(bytes: []const u8) !usize {
    if (failedBeforeSelection(bytes) or std.mem.indexOf(u8, bytes, strings.CHECK_COMPLETE) != null or
        std.mem.indexOf(u8, bytes, strings.READY) != null) return error.InvalidCancellationEvidence;
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
    const passed = try std.fmt.parseInt(usize, number[0..end], 10);
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

fn firmwareResult(bytes: []const u8) !?usize {
    if (std.mem.indexOf(u8, bytes, strings.READY) != null or
        std.mem.indexOf(u8, bytes, strings.CHECK_COMPLETE) != null) return error.UnexpectedFirmwareOutcome;
    const marker = std.mem.indexOf(u8, bytes, firmware.COMPLETE) orelse return null;
    const begin = try uniqueLine(bytes, firmware.BEGIN) orelse return error.MissingGuestChecks;
    if (begin >= marker or std.mem.count(u8, bytes, firmware.COMPLETE) != 1) return error.IncompleteGuestChecks;
    const number = bytes[marker + firmware.COMPLETE.len ..];
    const end = std.mem.indexOfAny(u8, number, strings.LINE_SEPARATORS) orelse return null;
    const passed = try std.fmt.parseInt(usize, number[0..end], 10);
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
