//! Encode AFS Read Requests With Explicit Length And Offset

const std = @import("std");

const Request = @import("shared").afs.types.service.request.Request;

pub fn encode(buffer: []u8, path: []const u8, offset: u64, count: u64) ?[]const u8 {
    const prefix = 2 * @sizeOf(u64);
    if (buffer.len < prefix or path.len > buffer.len - prefix) return null;
    std.mem.writeInt(u64, buffer[0..@sizeOf(u64)], offset, .little);
    std.mem.writeInt(u64, buffer[@sizeOf(u64)..prefix], count, .little);
    @memcpy(buffer[prefix..][0..path.len], path);
    return buffer[0 .. prefix + path.len];
}

pub fn decode(buffer: []const u8) ?Request {
    const prefix = 2 * @sizeOf(u64);
    if (buffer.len < prefix) return null;
    return .{
        .Offset = std.mem.readInt(u64, buffer[0..@sizeOf(u64)], .little),
        .Count = std.mem.readInt(u64, buffer[@sizeOf(u64)..prefix], .little),
        .Path = buffer[prefix..],
    };
}
