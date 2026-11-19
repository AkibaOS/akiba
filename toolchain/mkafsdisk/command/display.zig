//! Terminal Packing Updates And Persistent Image Statistics

const std = @import("std");

const limits = @import("../constants/display.zig");
const messages = @import("../strings/messages.zig");
const Report = @import("../types/report.zig").Report;

var visible: ?*const Progress = null;

pub const Progress = struct {
    Name: []const u8,
    Terminal: bool,
    Timer: ?std.time.Timer,
    LastDraw: u64 = 0,

    pub fn init(name: []const u8) Progress {
        const terminal = std.fs.File.stderr().getOrEnableAnsiEscapeSupport();
        return .{
            .Name = name,
            .Terminal = terminal,
            .Timer = if (terminal) std.time.Timer.start() catch null else null,
        };
    }

    pub fn update(self: *Progress, written: u32, total: u32) void {
        if (!self.Terminal) return;
        const now = if (self.Timer) |*timer| timer.read() else 0;
        // Give fast real packs a starting, advancing and final frame without a sleep.
        if (written > 1 and written < total and now - self.LastDraw < limits.REFRESH_NS) return;
        var buffer: [limits.PROGRESS_BYTES]u8 = undefined;
        const line = std.fmt.bufPrint(&buffer, messages.LIVE_PACKING, .{ written, total, self.Name }) catch return;
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        std.fs.File.stderr().writeAll(line) catch return;
        self.LastDraw = now;
        visible = self;
    }

    pub fn end(self: *const Progress) void {
        if (!self.Terminal) return;
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        if (visible == self) clear();
    }
};

pub fn report(name: []const u8, stats: Report) void {
    var buffer: [limits.REPORT_BYTES]u8 = undefined;
    const units = if (stats.Units == 1) messages.UNIT else messages.UNITS;
    const line = std.fmt.bufPrint(&buffer, messages.REPORT, .{
        name,                     stats.Units,          units,               stats.SizeBytes / limits.MIB_BYTES,
        stats.EspFirstSector,     stats.EspLastSector,  stats.EspClusters,   stats.BootloaderBytes,
        stats.BootloaderClusters, stats.AfsFirstSector, stats.AfsLastSector, stats.Stacks,
        stats.CellBytes,          stats.FreeCells,      stats.TotalCells,
    }) catch return;
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    clear();
    std.fs.File.stdout().writeAll(line) catch {};
}

fn clear() void {
    if (visible == null) return;
    visible = null;
    std.fs.File.stderr().writeAll(messages.CLEAR_LINE) catch {};
}
