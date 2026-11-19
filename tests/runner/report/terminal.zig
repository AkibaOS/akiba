//! Terminal Guest Check Results

const std = @import("std");

const labels = @import("tests").phase.strings.scenario;
const limits = @import("tests").runner.constants.limits;
const markers = @import("tests").phase.strings.serial;
const strings = @import("tests").runner.strings.runner;
const Scenario = @import("tests").phase.types.scenario.Scenario;
const Stage = @import("tests").runner.types.host.Stage;

pub fn begin() void {
    std.debug.print(strings.HEADER, .{});
}

pub fn passed(scenario: Scenario, count: usize, bytes: []const u8) void {
    if (scenario == .PulseDeath or scenario == .Collapse) {
        const name = if (scenario == .PulseDeath) labels.GROUP else labels.COLLAPSE_GROUP;
        std.debug.print(strings.GROUP_RESULT, .{ name, count });
        return;
    }
    var group: ?[]const u8 = null;
    var checks: usize = 0;
    var lines = std.mem.tokenizeAny(u8, bytes, strings.LINE_SEPARATORS);
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, markers.GROUP)) {
            if (group) |name| std.debug.print(strings.GROUP_RESULT, .{ name, checks });
            group = line[markers.GROUP.len..];
            checks = 0;
        } else if (std.mem.startsWith(u8, line, markers.PASS)) {
            checks += 1;
        }
    }
    if (group) |name| std.debug.print(strings.GROUP_RESULT, .{ name, checks });
}

pub fn fail(scenario: ?Scenario, stage: Stage, reason: anyerror, evidence: ?[]const u8) void {
    if (scenario) |selected| {
        std.debug.print(strings.PHASE_FAILURE, .{ @tagName(selected), @tagName(stage), @errorName(reason) });
    } else {
        std.debug.print(strings.FAILURE_RESULT, .{ @tagName(stage), @errorName(reason) });
    }
    const bytes = evidence orelse return;
    var lines = std.mem.tokenizeAny(u8, bytes, strings.LINE_SEPARATORS);
    var detailed = false;
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, markers.FAIL) or std.mem.startsWith(u8, line, strings.KERNEL_PANIC)) {
            std.debug.print(strings.FAILURE_DETAIL, .{line});
            detailed = true;
        }
    }
    if (detailed) return;
    var start = bytes.len;
    var remaining = limits.FAILURE_TAIL_LINES;
    while (start != 0 and remaining != 0) {
        start -= 1;
        if (bytes[start] == '\n') remaining -= 1;
    }
    var tail = std.mem.tokenizeAny(u8, bytes[start..], strings.LINE_SEPARATORS);
    while (tail.next()) |line| std.debug.print(strings.FAILURE_DETAIL, .{line});
}

pub fn cleanup(started: bool, failure: ?anyerror, verified: bool) void {
    if (failure) |reason| {
        std.debug.print(strings.CLEANUP_FAIL, .{@errorName(reason)});
    } else if (!verified) {
        std.debug.print(strings.CLEANUP_FAIL, .{strings.FAILED});
    } else if (started) {
        std.debug.print(strings.CLEANUP_PASS, .{});
    }
}

pub fn failedTotal(check_count: usize, phase_count: usize) void {
    std.debug.print(strings.FAILED_TOTAL, .{ check_count, phase_count });
}

pub fn total(count: usize) void {
    std.debug.print(strings.TOTAL_RESULT, .{count});
}
