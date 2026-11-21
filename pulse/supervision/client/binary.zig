//! Launch A Configured Service Through The Installed Weaver

const std = @import("std");

const codec = @import("shared").launch.service.request;
const defaults = @import("pulse").world.constants.defaults;
const invoke = @import("personaasm").invoke;
const letters = @import("shared").launch.constants.service.postman;
const limits = @import("shared").persona.constants.postman;
const service = @import("pulse").supervision.client.service;

const Call = @import("shared").persona.types.call.Call;
const Header = @import("shared").persona.types.letter.Header;
const Job = @import("pulse").world.types.parse.document.Job;
const Status = @import("shared").persona.types.invocation.Status;

pub fn start(allocator: std.mem.Allocator, weaver: u64, pulse: u64, job: Job) !u64 {
    const length = std.math.add(usize, @sizeOf(u64), job.Parameters.len) catch return error.TooLarge;
    const parameters = try allocator.alloc(u8, length);
    defer allocator.free(parameters);
    std.mem.writeInt(u64, parameters[0..@sizeOf(u64)], pulse, .little);
    @memcpy(parameters[@sizeOf(u64)..], job.Parameters);
    var buffer: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    const payload = codec.encode(&buffer, job.Binary, parameters) orelse return error.TooLarge;
    var child: u64 = 0;
    var header: Header = undefined;
    const descriptor: Call = .{
        .Destination = weaver,
        .Type = letters.LAUNCH,
        .Request = @intFromPtr(payload.ptr),
        .RequestLength = payload.len,
        .Reply = @intFromPtr(&child),
        .ReplyCapacity = @sizeOf(u64),
        .Metadata = @intFromPtr(&header),
    };
    const response = invoke.call(.CallTimed, @intFromPtr(&descriptor), defaults.LAUNCH_TICKS, 0, 0);
    if (response.Status == @intFromEnum(Status.TimedOut) and response.Value != 0) {
        try service.terminate(response.Value);
        if (!service.wait(response.Value, defaults.LAUNCH_TICKS)) return error.ShutdownFailed;
        try service.collect(response.Value);
    }
    if (response.Status != @intFromEnum(Status.Success) or response.Value != @sizeOf(u64) or child == 0 or
        header.Sender != weaver or header.Type != letters.STARTED or header.Length != @sizeOf(u64) or header.ReplyTicket != 0)
        return error.LaunchFailed;
    return child;
}
