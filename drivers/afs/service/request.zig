//! Dispatch Read Only AFS Unit And Stack Operations

const std = @import("std");

const afs = @import("shared").afs;
const limits = @import("shared").persona.constants.postman;
const letters = @import("shared").afs.constants.service.postman;

const Catalog = afs.types.reader.Catalog;
const Reply = @import("afs").types.service.reply.Reply;
const Request = afs.types.service.request.Request;

pub fn respond(catalog: *const Catalog, kind: u64, input: []const u8, output: []u8, scratch: []u8) Reply {
    const query = afs.service.request.decode(input) orelse return .{ .Kind = letters.REFUSED };
    if (query.Count > output.len) return .{ .Kind = letters.REFUSED };
    var components: [limits.MAX_PAYLOAD_BYTES / 2 + 1][]const u8 = undefined;
    const path = split(query.Path, &components) orelse return .{ .Kind = letters.REFUSED };
    return switch (kind) {
        letters.LIST => if (query.Count == 0) list(catalog, path, query.Offset, output, scratch) else .{ .Kind = letters.REFUSED },
        letters.STAT, letters.READ => if (path.len != 0) unit(catalog, path, kind, query, output, scratch) else .{ .Kind = letters.REFUSED },
        else => .{ .Kind = letters.REFUSED },
    };
}

fn split(bytes: []const u8, components: [][]const u8) ?[]const []const u8 {
    if (bytes.len == 0) return components[0..0];
    var parts = std.mem.splitScalar(u8, bytes, letters.PATH_SEPARATOR);
    var count: usize = 0;
    while (parts.next()) |name| {
        if (name.len == 0 or count == components.len) return null;
        components[count] = name;
        count += 1;
    }
    return components[0..count];
}

fn list(catalog: *const Catalog, path: []const []const u8, index: u64, output: []u8, scratch: []u8) Reply {
    const found = afs.read.list.child(catalog, path, index, scratch) catch |failure|
        return .{ .Kind = if (failure == error.MissingStack) letters.MISSING else letters.REFUSED };
    const entry = found orelse return .{ .Kind = letters.END };
    const bytes = std.mem.asBytes(&entry);
    if (output.len < bytes.len) return .{ .Kind = letters.REFUSED };
    @memcpy(output[0..bytes.len], bytes);
    return .{ .Kind = letters.ENTRY, .Length = bytes.len };
}

fn unit(catalog: *const Catalog, path: []const []const u8, kind: u64, query: Request, output: []u8, scratch: []u8) Reply {
    const parents = path[0 .. path.len - 1];
    const name = path[path.len - 1];
    const found = afs.read.catalog.open(catalog, parents, name, scratch) catch return .{ .Kind = letters.REFUSED };
    const record = found orelse return .{ .Kind = letters.MISSING };
    if (kind == letters.STAT) {
        if (query.Offset != 0 or query.Count != 0 or output.len < @sizeOf(u64)) return .{ .Kind = letters.REFUSED };
        const size = afs.read.unit.size(&catalog.Reader, &record.DataChannel) catch return .{ .Kind = letters.REFUSED };
        std.mem.writeInt(u64, output[0..@sizeOf(u64)], size, .little);
        return .{ .Kind = letters.SIZE, .Length = @sizeOf(u64) };
    }
    const size = afs.read.range.unit(&catalog.Reader, &record, query.Offset, output[0..@intCast(query.Count)], scratch) catch
        return .{ .Kind = letters.REFUSED };
    return .{ .Kind = letters.DATA, .Length = size };
}
