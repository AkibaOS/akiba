//! Verify Actual QEMU Scanout Pixels Before Restoring The Guest

const std = @import("std");

const pattern = @import("tests").phase.constants.display;
const protocol = @import("tests").runner.transport.protocol;
const strings = @import("tests").runner.strings.runner;
const wire = @import("tests").phase.strings.display;

const Connection = @import("tests").runner.types.host.Connection;

pub fn capture(allocator: std.mem.Allocator, connection: *Connection, directory: []const u8, evidence: []const u8) !void {
    var lines = std.mem.tokenizeAny(u8, evidence, strings.LINE_SEPARATORS);
    var witnesses: usize = 0;
    while (lines.next()) |line| if (std.mem.eql(u8, line, wire.PRESENTED)) {
        witnesses += 1;
    };
    if (witnesses != 1) return error.InvalidDiagnosticDisplay;
    const path = try std.fs.path.join(allocator, &.{ directory, wire.FILE });
    defer allocator.free(path);
    const arguments = try std.json.Stringify.valueAlloc(allocator, .{ .filename = path }, .{});
    defer allocator.free(arguments);
    try protocol.action(allocator, connection, wire.SCREENDUMP, arguments);
    const info = try std.fs.cwd().statFile(path);
    if (info.kind != .file) return error.InvalidDisplayScanout;
    const size = std.math.cast(usize, info.size) orelse return error.InvalidDisplayScanout;
    const bytes = try std.fs.cwd().readFileAlloc(allocator, path, size);
    defer allocator.free(bytes);
    try verify(bytes);
    std.debug.print(wire.VERIFIED, .{});
}

pub fn verify(bytes: []const u8) !void {
    var offset: usize = 0;
    if (!std.mem.eql(u8, try token(bytes, &offset), wire.MAGIC)) return error.InvalidDisplayScanout;
    const width = try number(bytes, &offset);
    const height = try number(bytes, &offset);
    if (try number(bytes, &offset) != std.math.maxInt(u8)) return error.InvalidDisplayScanout;
    if (offset >= bytes.len or !std.ascii.isWhitespace(bytes[offset])) return error.InvalidDisplayScanout;
    if (bytes[offset] == '\r' and offset + 1 < bytes.len and bytes[offset + 1] == '\n') offset += 1;
    offset += 1;
    if (width < pattern.WIDTH or height < pattern.TOP + pattern.HEIGHT) return error.InvalidDisplayScanout;
    const stride = std.math.mul(usize, width, pattern.RGB_BYTES) catch return error.InvalidDisplayScanout;
    const expected = std.math.mul(usize, stride, height) catch return error.InvalidDisplayScanout;
    const pixels = bytes[offset..];
    if (pixels.len != expected) return error.InvalidDisplayScanout;
    const first = pattern.TOP * stride + (width - pattern.WIDTH) * pattern.RGB_BYTES;
    for (pattern.PATTERN, 0..) |row, index| {
        const start = first + index * stride;
        if (!std.mem.eql(u8, pixels[start..][0 .. pattern.WIDTH * pattern.RGB_BYTES], std.mem.asBytes(&row)))
            return error.DisplayPixelsMismatch;
    }
}

fn number(bytes: []const u8, offset: *usize) !usize {
    return std.fmt.parseInt(usize, try token(bytes, offset), 10) catch error.InvalidDisplayScanout;
}

fn token(bytes: []const u8, offset: *usize) ![]const u8 {
    while (offset.* < bytes.len) {
        if (std.ascii.isWhitespace(bytes[offset.*])) {
            offset.* += 1;
        } else if (bytes[offset.*] == '#') {
            while (offset.* < bytes.len and bytes[offset.*] != '\n') offset.* += 1;
        } else break;
    }
    const start = offset.*;
    while (offset.* < bytes.len and !std.ascii.isWhitespace(bytes[offset.*])) offset.* += 1;
    if (start == offset.*) return error.InvalidDisplayScanout;
    return bytes[start..offset.*];
}
