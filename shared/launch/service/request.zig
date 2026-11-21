//! Encode A Canonical System Binary Unit Launch

const std = @import("std");

const Request = @import("shared").launch.types.service.request.Request;

pub fn encode(output: []u8, identity: []const u8, parameters: []const u8) ?[]const u8 {
    const prefix = @sizeOf(u64);
    if (output.len < prefix or !valid(identity) or identity.len > output.len - prefix or
        parameters.len > output.len - prefix - identity.len) return null;
    const end = prefix + identity.len;
    std.mem.writeInt(u64, output[0..prefix], identity.len, .little);
    @memcpy(output[prefix..end], identity);
    @memcpy(output[end..][0..parameters.len], parameters);
    return output[0 .. end + parameters.len];
}

pub fn decode(bytes: []const u8) ?Request {
    const prefix = @sizeOf(u64);
    if (bytes.len < prefix) return null;
    const length = std.mem.readInt(u64, bytes[0..prefix], .little);
    if (length > bytes.len - prefix) return null;
    const end = prefix + length;
    const identity = bytes[prefix..end];
    if (!valid(identity)) return null;
    return .{ .Identity = identity, .Parameters = bytes[end..] };
}

fn valid(identity: []const u8) bool {
    if (identity.len == 0 or (identity.len <= 2 and std.mem.allEqual(u8, identity, '.'))) return false;
    for (identity) |byte| if (byte < ' ' or byte == '/' or byte == '\\') return false;
    return true;
}
