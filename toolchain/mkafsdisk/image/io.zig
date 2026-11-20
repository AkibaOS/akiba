//! Native Disk Image I O Backend

const std = @import("std");

const tool = @import("mkafsdisk");

pub fn native() tool.types.io.Operations {
    return .{ .ReadFn = readFile, .WriteFn = writeFile, .SyncFn = syncFile, .RenameFn = renameOutput };
}

pub fn readExact(operations: tool.types.io.Operations, file: std.fs.File, buffer: []u8) !void {
    var offset: usize = 0;
    while (offset < buffer.len) {
        const count = try operations.ReadFn(operations.Context, file, buffer[offset..]);
        if (count == 0 or count > buffer.len - offset) return tool.errors.image.creation.ImageError.SourceChanged;
        offset += count;
    }
}

fn readFile(_: ?*anyopaque, file: std.fs.File, buffer: []u8) !usize {
    return file.read(buffer);
}

fn writeFile(_: ?*anyopaque, file: std.fs.File, buffer: []const u8, offset: u64) !void {
    try file.pwriteAll(buffer, offset);
}

fn syncFile(_: ?*anyopaque, file: std.fs.File) !void {
    try file.sync();
}

fn renameOutput(_: ?*anyopaque, atomic: *std.fs.AtomicFile) !void {
    try atomic.renameIntoPlace();
}
