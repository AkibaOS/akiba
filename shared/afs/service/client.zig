//! Read Owned Unit Snapshots Through An Authenticated AFS Endpoint

const std = @import("std");

const codec = @import("shared").afs.service.request;
const letters = @import("shared").afs.constants.service.postman;
const limits = @import("shared").persona.constants.postman;

const Call = @import("shared").persona.types.call.Call;
const Client = @import("shared").afs.types.service.client.Client;
const ClientError = @import("shared").afs.errors.service.client.ClientError;
const Header = @import("shared").persona.types.letter.Header;
const Reply = @import("shared").afs.types.service.client.Reply;
const Status = @import("shared").persona.types.invocation.Status;

pub fn readAll(client: Client, allocator: std.mem.Allocator, path: []const u8) ClientError!?[]u8 {
    var encoded_size: [@sizeOf(u64)]u8 = undefined;
    const stat = try request(client, letters.STAT, path, 0, 0, &encoded_size);
    if (stat.Kind == letters.MISSING and stat.Length == 0) return null;
    if (stat.Kind != letters.SIZE or stat.Length != encoded_size.len) return error.ReadFailed;
    const length = std.math.cast(usize, std.mem.readInt(u64, &encoded_size, .little)) orelse return error.OutOfMemory;
    const bytes = try allocator.alloc(u8, length);
    errdefer allocator.free(bytes);
    var offset: usize = 0;
    while (offset < bytes.len) {
        const count = @min(bytes.len - offset, limits.MAX_PAYLOAD_BYTES);
        const read = try request(client, letters.READ, path, offset, count, bytes[offset..][0..count]);
        if (read.Kind != letters.DATA or read.Length != count) return error.ReadFailed;
        offset += count;
    }
    return bytes;
}

pub fn request(client: Client, operation: u64, path: []const u8, offset: u64, count: u64, output: []u8) ClientError!Reply {
    var buffer: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    const payload = codec.encode(&buffer, path, offset, count) orelse return error.ReadFailed;
    var header: Header = undefined;
    const descriptor: Call = .{
        .Destination = client.Endpoint,
        .Type = operation,
        .Request = @intFromPtr(payload.ptr),
        .RequestLength = payload.len,
        .Reply = @intFromPtr(output.ptr),
        .ReplyCapacity = output.len,
        .Metadata = @intFromPtr(&header),
    };
    const result = client.Invoke(&descriptor, client.Timeout);
    if (result.Status != @intFromEnum(Status.Success) or header.Sender != client.Endpoint or header.ReplyTicket != 0 or
        result.Value != header.Length or result.Value > output.len) return error.ReadFailed;
    return .{ .Kind = header.Type, .Length = @intCast(result.Value) };
}
