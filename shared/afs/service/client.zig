//! Read Owned Unit Snapshots Through An Authenticated AFS Endpoint

const std = @import("std");

const codec = @import("shared").afs.service.request;
const letters = @import("shared").afs.constants.service.postman;
const limits = @import("shared").persona.constants.postman;

const Call = @import("shared").persona.types.call.Call;
const Client = @import("shared").afs.types.service.client.Client;
const ClientError = @import("shared").afs.errors.service.client.ClientError;
const Entry = @import("shared").afs.types.read.list.Entry;
const EntryKind = @import("shared").afs.types.read.list.Kind;
const Header = @import("shared").persona.types.letter.Header;
const Reply = @import("shared").afs.types.service.client.Reply;
const Status = @import("shared").persona.types.invocation.Status;

pub fn readAll(client: Client, allocator: std.mem.Allocator, path: []const u8) ClientError!?[]u8 {
    return readWithin(client, allocator, path, std.math.maxInt(usize));
}

pub fn readWithin(client: Client, allocator: std.mem.Allocator, path: []const u8, maximum: usize) ClientError!?[]u8 {
    const length = std.math.cast(usize, (try stat(client, path)) orelse return null) orelse return error.TooLarge;
    if (length > maximum) return error.TooLarge;
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

pub fn stat(client: Client, path: []const u8) ClientError!?u64 {
    var encoded: [@sizeOf(u64)]u8 = undefined;
    const reply = try request(client, letters.STAT, path, 0, 0, &encoded);
    if (reply.Kind == letters.MISSING and reply.Length == 0) return null;
    if (reply.Kind != letters.SIZE or reply.Length != encoded.len) return error.ReadFailed;
    return std.mem.readInt(u64, &encoded, .little);
}

pub fn list(client: Client, path: []const u8, index: u64) (ClientError || error{MissingStack})!?Entry {
    var encoded: [@sizeOf(Entry)]u8 = undefined;
    const reply = try request(client, letters.LIST, path, index, 0, &encoded);
    if (reply.Kind == letters.MISSING and reply.Length == 0) return error.MissingStack;
    if (reply.Kind == letters.END and reply.Length == 0) return null;
    if (reply.Kind != letters.ENTRY or reply.Length != encoded.len) return error.ReadFailed;
    const raw = std.mem.readInt(u16, encoded[@offsetOf(Entry, "Kind")..][0..@sizeOf(u16)], .little);
    if (raw != @intFromEnum(EntryKind.Stack) and raw != @intFromEnum(EntryKind.Unit)) return error.ReadFailed;
    const entry = std.mem.bytesToValue(Entry, &encoded);
    if (entry.Length == 0 or entry.Length > entry.Identity.len) return error.ReadFailed;
    return entry;
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
