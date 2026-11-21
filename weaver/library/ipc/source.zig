//! Adapt The Shared AFS Client To Weaver Owned Library Snapshots

const std = @import("std");

const afs = @import("shared").afs;
const invoke = @import("personaasm").invoke;
const letters = afs.constants.service.postman;

const Call = @import("shared").persona.types.call.Call;
const ReadError = @import("weaver").library.errors.library.ReadError;
const Result = @import("shared").persona.types.result.Result;
const Source = @import("weaver").library.types.source.Source;

pub fn source(endpoint: *const u64) Source {
    return .{ .Context = endpoint, .ReadFromOrigin = read };
}

pub fn read(context: *const anyopaque, allocator: std.mem.Allocator, parents: []const []const u8, unit: []const u8) ReadError!?[]u8 {
    const endpoint: *const u64 = @ptrCast(@alignCast(context));
    var path: std.ArrayList(u8) = .empty;
    defer path.deinit(allocator);
    for (parents) |parent| {
        try path.appendSlice(allocator, parent);
        try path.append(allocator, letters.PATH_SEPARATOR);
    }
    try path.appendSlice(allocator, unit);
    return afs.service.client.readAll(.{ .Endpoint = endpoint.*, .Timeout = letters.TIMEOUT_TICKS, .Invoke = exchange }, allocator, path.items) catch |failure|
        return if (failure == error.OutOfMemory) error.OutOfMemory else error.LibraryReadFailed;
}

fn exchange(descriptor: *const Call, ticks: u64) Result {
    const result = invoke.call(.CallTimed, @intFromPtr(descriptor), ticks, 0, 0);
    return .{ .Status = result.Status, .Value = result.Value };
}
