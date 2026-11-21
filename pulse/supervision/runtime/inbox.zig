//! Wait For Service Outcomes And Authenticated Supervisor Requests

const std = @import("std");

const drive = @import("pulse").supervision.runtime.drive;
const invoke = @import("personaasm").invoke;
const legacy = @import("shared").pulse.constants.status;
const limits = @import("shared").persona.constants.postman;
const policy = @import("pulse").supervision.plan.model;
const protocol = @import("shared").pulse.constants.supervision.protocol;
const pulse = @import("pulse").supervision.inbox;

const Context = @import("pulse").supervision.types.runtime.context.Context;
const Header = @import("shared").persona.types.letter.Header;
const Snapshot = @import("shared").pulse.types.supervision.report.Snapshot;
const Status = @import("shared").persona.types.invocation.Status;

pub fn listen(context: *Context) noreturn {
    var payload: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    var header: Header = undefined;
    while (true) {
        const arrived = invoke.call(.ReceiveActivity, @intFromPtr(&payload), payload.len, @intFromPtr(&header), 0);
        if (arrived.Status == @intFromEnum(Status.ChildReady)) {
            drive.outcome(context, arrived.Value) catch {
                context.Phase = .Degraded;
                policy.shutdown(context.Plan);
            };
            progress(context);
            continue;
        }
        if (arrived.Status != @intFromEnum(Status.Success)) pulse.stop(arrived.Status);
        const bytes = payload[0..@intCast(@min(payload.len, arrived.Value))];
        var report: Snapshot = undefined;
        var length: usize = 0;
        const kind = answer: {
            if (header.Length != bytes.len) break :answer protocol.REFUSED;
            if (header.Type == legacy.QUERY and bytes.len == 0) break :answer legacy.READY;
            if (header.Type == protocol.REPORT and (bytes.len == 0 or bytes.len == @sizeOf(u64))) {
                const index = if (bytes.len == 0) std.math.maxInt(u64) else std.mem.readInt(u64, bytes[0..@sizeOf(u64)], .little);
                report = snapshot(context, index);
                length = @sizeOf(Snapshot);
                break :answer protocol.SNAPSHOT;
            }
            if (header.Type == protocol.SHUTDOWN and bytes.len == 0 and controller(context, header.Sender)) {
                context.Phase = .Stopping;
                policy.shutdown(context.Plan);
                break :answer protocol.SERVICE_STOPPED;
            }
            break :answer legacy.UNSUPPORTED;
        };
        if (header.ReplyTicket != 0) {
            const replied = invoke.call(.Reply, header.ReplyTicket, if (length == 0) 0 else @intFromPtr(&report), length, kind);
            switch (replied.Status) {
                @intFromEnum(Status.Success), @intFromEnum(Status.PeerGone), @intFromEnum(Status.InvalidReply) => {},
                else => pulse.stop(replied.Status),
            }
        }
        progress(context);
    }
}

fn progress(context: *Context) void {
    drive.run(context) catch {
        context.Phase = .Degraded;
        policy.shutdown(context.Plan);
    };
}

fn controller(context: *const Context, identifier: u64) bool {
    for (context.Plan.Jobs, context.Plan.Services) |job, running| {
        if (job.Controller and running.ID == identifier and running.Stage == .Ready) return true;
    }
    return false;
}

fn snapshot(context: *const Context, ordinal: u64) Snapshot {
    var report: Snapshot = .{
        .Phase = context.Phase,
        .Count = context.Plan.Jobs.len,
        .WeaverID = context.WeaverID,
        .AfsID = context.AfsID,
        .DiskID = context.DiskID,
    };
    if (ordinal < context.Plan.Services.len) {
        const running = context.Plan.Services[@intCast(ordinal)];
        report.ID = running.ID;
        report.Stage = @intFromEnum(running.Stage);
        report.Starts = running.Starts;
        report.Failures = running.Failures;
        report.StartedAt = running.StartedAt;
        report.StoppedAt = running.StoppedAt;
    }
    return report;
}
