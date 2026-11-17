//! Canonical Host Source And Output Separation

const builtin = @import("builtin");
const std = @import("std");

const tool = @import("mkafsdisk");

pub fn validateOutput(allocator: std.mem.Allocator, source_location: []const u8, output_path: []const u8) !void {
    var source_directory = try std.fs.cwd().openDir(source_location, .{ .no_follow = true });
    defer source_directory.close();
    const source = try source_directory.realpathAlloc(allocator, tool.strings.names.ENTRY_CURRENT);
    defer allocator.free(source);
    const parent_path = std.fs.path.dirname(output_path) orelse tool.strings.names.ENTRY_CURRENT;
    var output_directory = try std.fs.cwd().openDir(parent_path, .{});
    defer output_directory.close();
    const parent = try output_directory.realpathAlloc(allocator, tool.strings.names.ENTRY_CURRENT);
    defer allocator.free(parent);
    if (isWithin(parent, source)) return tool.errors.image.ImageError.OutputInsideSource;
    const existing: ?[]u8 = std.fs.cwd().realpathAlloc(allocator, output_path) catch |failure| switch (failure) {
        error.FileNotFound => null,
        else => return failure,
    };
    if (existing) |resolved| {
        defer allocator.free(resolved);
        if (isWithin(resolved, source)) return tool.errors.image.ImageError.OutputInsideSource;
    }
}

fn isWithin(candidate: []const u8, source: []const u8) bool {
    if (candidate.len < source.len) return false;
    const prefix = candidate[0..source.len];
    const equal = if (builtin.os.tag == .windows) std.ascii.eqlIgnoreCase(prefix, source) else std.mem.eql(u8, prefix, source);
    if (!equal) return false;
    return candidate.len == source.len or std.fs.path.isSep(source[source.len - 1]) or std.fs.path.isSep(candidate[source.len]);
}
