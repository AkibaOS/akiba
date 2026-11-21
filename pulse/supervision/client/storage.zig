//! Read Pulse Configuration Through The Shared AFS Client

const std = @import("std");

const afs = @import("shared").afs;
const invoke = @import("personaasm").invoke;
const limits = @import("pulse").world.constants.defaults;

const Call = @import("shared").persona.types.call.Call;
const Client = @import("shared").afs.types.service.client.Client;
const Result = @import("shared").persona.types.result.Result;

pub fn read(endpoint: u64, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return (try afs.service.client.readAll(client(endpoint), allocator, path)) orelse error.WorldMissing;
}

pub fn client(endpoint: u64) Client {
    return .{ .Endpoint = endpoint, .Timeout = limits.TIMEOUT_TICKS, .Invoke = exchange };
}

fn exchange(descriptor: *const Call, ticks: u64) Result {
    const result = invoke.call(.CallTimed, @intFromPtr(descriptor), ticks, 0, 0);
    return .{ .Status = result.Status, .Value = result.Value };
}
