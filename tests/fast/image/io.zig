//! File Backed Image Read Adapters

const std = @import("std");

const afs = @import("shared").afs;
const types = @import("tests").fast.types.image.fixtures;

const AFSImage = types.AFSImage;
const BlockError = afs.errors.block.BlockError;
const BlockReader = afs.types.block.BlockReader;
const FileDevice = types.FileDevice;

pub fn readExact(file: std.fs.File, offset: u64, buffer: []u8) !void {
    try std.testing.expectEqual(buffer.len, try file.preadAll(buffer, offset));
}

pub fn expectZeros(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}

pub fn reader(image: *AFSImage) BlockReader {
    return .{
        .Context = &image.Device,
        .ReadFn = readCell,
        .CellSize = image.Header.CellSize,
        .TotalCells = image.Header.TotalCells,
    };
}

fn readCell(context: *anyopaque, cell: u64, buffer: []u8) BlockError!void {
    const device: *FileDevice = @ptrCast(@alignCast(context));
    const offset = device.PartitionStart + cell * device.CellSize;
    const completed = device.File.preadAll(buffer, offset) catch return BlockError.ReadFailed;
    if (completed != buffer.len) return BlockError.ReadFailed;
}
