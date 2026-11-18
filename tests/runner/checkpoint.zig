//! Cold VM Snapshot Jobs

const std = @import("std");

const limits = @import("tests").constants.runner;
const process = @import("tests").runner.process;
const protocol = @import("tests").runner.protocol;
const strings = @import("tests").strings.runner;
const types = @import("tests").types.host;

pub fn run(allocator: std.mem.Allocator, instance: *types.Process, connection: *types.Connection, operation: []const u8) !void {
    var timer = try std.time.Timer.start();
    const deadline: types.Deadline = .{ .Timer = &timer, .Limit = limits.SNAPSHOT_NS };
    const started = try protocol.commandWithin(allocator, connection, operation, strings.SNAPSHOT_ARGUMENTS, deadline);
    started.deinit();
    while (true) {
        if (process.cancelled()) return error.Cancelled;
        if (try process.exited(instance)) return error.GuestExited;
        if (timer.read() >= limits.SNAPSHOT_NS) return error.SnapshotJobTimeout;
        const reply = try protocol.commandWithin(allocator, connection, strings.QUERY_JOBS, null, deadline);
        defer reply.deinit();
        if (try concluded(protocol.returned(reply), strings.SNAPSHOT_ID)) {
            if (timer.read() >= limits.SNAPSHOT_NS) return error.SnapshotJobTimeout;
            const dismissed = try protocol.commandWithin(allocator, connection, strings.JOB_DISMISS, strings.DISMISS_ARGUMENTS, deadline);
            dismissed.deinit();
            return;
        }
        std.Thread.sleep(limits.POLL_NS);
    }
}

pub fn concluded(jobs: std.json.Value, id: []const u8) !bool {
    if (jobs != .array) return error.QmpInvalidResponse;
    var matched: ?std.json.Value = null;
    for (jobs.array.items) |job| {
        if (!protocol.equal(job, strings.QMP_ID, id)) continue;
        if (matched != null) return error.QmpInvalidResponse;
        matched = job;
    }
    const job = matched orelse return error.SnapshotJobLost;
    const status = protocol.text(job, strings.STATUS) orelse return error.QmpInvalidResponse;
    if (!std.mem.eql(u8, status, strings.CONCLUDED)) return false;
    if (protocol.field(job, strings.QMP_ERROR) != null) return error.SnapshotJobFailed;
    return true;
}
