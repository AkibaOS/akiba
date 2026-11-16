//! Terminal Guest Check Results

const std = @import("std");

const labels = @import("tests").strings.scenario;
const limits = @import("tests").constants.runner;
const strings = @import("tests").strings.runner;
const Report = @import("tests").types.host.Report;

pub fn begin() void {
    std.debug.print(strings.HEADER, .{});
}

pub fn finish(report: *const Report, bytes: ?[]const u8) void {
    if (report.Error) |reason| {
        std.debug.print(strings.FAILURE_RESULT, .{ @tagName(report.Stage), reason });
        if (bytes) |data| {
            var lines = std.mem.tokenizeAny(u8, data, strings.LINE_SEPARATORS);
            var detailed = false;
            while (lines.next()) |line| {
                if (std.mem.startsWith(u8, line, strings.CHECK_FAIL) or std.mem.startsWith(u8, line, strings.KERNEL_PANIC)) {
                    std.debug.print(strings.FAILURE_DETAIL, .{line});
                    detailed = true;
                }
            }
            if (!detailed) {
                var start = data.len;
                var remaining = limits.FAILURE_TAIL_LINES;
                while (start != 0 and remaining != 0) {
                    start -= 1;
                    if (data[start] == '\n') remaining -= 1;
                }
                var tail = std.mem.tokenizeAny(u8, data[start..], strings.LINE_SEPARATORS);
                while (tail.next()) |line| std.debug.print(strings.FAILURE_DETAIL, .{line});
            }
        }
    } else if (report.Scenario == .PulseDeath) {
        std.debug.print(strings.GROUP_RESULT, .{ labels.GROUP, report.Passed });
    } else if (bytes) |data| {
        var group: ?[]const u8 = null;
        var passed: usize = 0;
        var lines = std.mem.tokenizeAny(u8, data, strings.LINE_SEPARATORS);
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, strings.GROUP_PREFIX)) {
                if (group) |name| std.debug.print(strings.GROUP_RESULT, .{ name, passed });
                group = line[strings.GROUP_PREFIX.len..];
                passed = 0;
            } else if (std.mem.startsWith(u8, line, strings.CHECK_PASS)) {
                passed += 1;
            }
        }
        if (group) |name| std.debug.print(strings.GROUP_RESULT, .{ name, passed });
    }
    if (report.CleanupVerified) {
        std.debug.print(strings.CLEANUP_PASS, .{});
    } else {
        std.debug.print(strings.CLEANUP_FAIL, .{report.CleanupError orelse report.Error orelse strings.FAILED});
    }
    if (report.Error == null) std.debug.print(strings.TOTAL_RESULT, .{report.Passed});
}
