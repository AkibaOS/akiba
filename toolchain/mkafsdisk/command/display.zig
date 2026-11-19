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
        // Every short-pack update is cheap; only the middle of larger packs is coalesced.
        if (total > limits.SHORT_PACK_UNITS and written > 1 and written < total and now - self.LastDraw < limits.REFRESH_NS) return;
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

pub fn report(name: []const u8, destination: []const u8, source: []const u8, stats: Report) void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    clear();
    var buffer: [limits.REPORT_BUFFER_BYTES]u8 = undefined;
    var stdout = std.fs.File.stdout().writerStreaming(&buffer);
    writeReport(&stdout.interface, name, destination, source, stats) catch return;
    stdout.interface.flush() catch {};
}

pub fn writeReport(output: *std.Io.Writer, name: []const u8, destination: []const u8, source: []const u8, stats: Report) !void {
    return output.print(messages.REPORT, .{
        stats.Units,          stats.Units,           name,
        destination,          source,                stats.SizeBytes / limits.MIB_BYTES,
        stats.EspFirstSector, stats.EspLastSector,   stats.AfsFirstSector,
        stats.AfsLastSector,  stats.BootloaderBytes, stats.BootloaderClusters,
        stats.EspClusters,    stats.TotalCells,      stats.CellBytes,
        stats.Units,          stats.Stacks,          stats.FreeCells,
    });
}

fn clear() void {
    if (visible == null) return;
    visible = null;
    std.fs.File.stderr().writeAll(messages.CLEAR_LINE) catch {};
}
