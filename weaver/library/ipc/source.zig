//! Fetch Owned Installed Unit Snapshots Through AFS Postman

const std = @import("std");

const afs = @import("shared").afs;
const invoke = @import("personaasm").invoke;
const letters = afs.constants.service.postman;
const limits = @import("shared").persona.constants.postman;

const Call = @import("shared").persona.types.call.Call;
const Header = @import("shared").persona.types.letter.Header;
const ReadError = @import("weaver").library.errors.library.ReadError;
const Source = @import("weaver").library.types.source.Source;
const Status = @import("shared").persona.types.invocation.Status;

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
    var size: [@sizeOf(u64)]u8 = undefined;
    if (!try request(endpoint.*, letters.STAT, path.items, 0, &size)) return null;
    const length = std.math.cast(usize, std.mem.readInt(u64, &size, .little)) orelse return error.OutOfMemory;
    const bytes = try allocator.alloc(u8, length);
    errdefer allocator.free(bytes);
    var offset: usize = 0;
    while (offset < bytes.len) {
        const count = @min(bytes.len - offset, limits.MAX_PAYLOAD_BYTES);
        if (!try request(endpoint.*, letters.READ, path.items, offset, bytes[offset..][0..count])) return error.LibraryReadFailed;
        offset += count;
    }
    return bytes;
}

fn request(endpoint: u64, operation: u64, path: []const u8, offset: u64, output: []u8) ReadError!bool {
    var buffer: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    const input = afs.service.request.encode(&buffer, path, offset, if (operation == letters.READ) output.len else 0) orelse return error.LibraryReadFailed;
    var header: Header = undefined;
    const descriptor: Call = .{
        .Destination = endpoint,
        .Type = operation,
        .Request = @intFromPtr(input.ptr),
        .RequestLength = input.len,
        .Reply = @intFromPtr(output.ptr),
        .ReplyCapacity = output.len,
        .Metadata = @intFromPtr(&header),
    };
    const result = invoke.call(.Call, @intFromPtr(&descriptor), 0, 0, 0);
    if (result.Status != @intFromEnum(Status.Success) or header.Sender != endpoint or header.ReplyTicket != 0) return error.LibraryReadFailed;
    if (header.Type == letters.MISSING and header.Length == 0 and result.Value == 0) return false;
    const expected = if (operation == letters.STAT) letters.SIZE else letters.DATA;
    if (result.Value != output.len or header.Length != output.len or header.Type != expected) return error.LibraryReadFailed;
    return true;
}
