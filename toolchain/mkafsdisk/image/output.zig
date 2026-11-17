//! Same Directory Disk Image Output Creation

const std = @import("std");

const tool = @import("mkafsdisk");

pub fn create(output_path: []const u8, total_bytes: u64) !tool.types.output.Output {
    var atomic = try std.fs.cwd().atomicFile(output_path, .{ .write_buffer = &.{} });
    errdefer atomic.deinit();
    try atomic.file_writer.file.setEndPos(total_bytes);
    return .{ .Atomic = atomic, .ExpectedBytes = total_bytes };
}
