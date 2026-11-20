//! Expose Bounded AFS Cells Over Native Read Only Sectors

const std = @import("std");

const afs = @import("shared").afs;

const BlockError = afs.errors.block.BlockError;
const BlockReader = afs.types.block.BlockReader;
const ReadError = afs.errors.read.transfers.ReadError;
const SectorVolume = afs.types.read.sectors.SectorVolume;
const Source = @import("shared").storage.types.sector.Source;
const VolumeHeader = afs.types.volume.VolumeHeader;

pub fn open(source: Source, first_lba: u64, last_lba: u64, scratch: []u8) ReadError!SectorVolume {
    if (first_lba > last_lba or last_lba > source.LastLBA or source.BlockBytes < @sizeOf(VolumeHeader) or
        !std.math.isPowerOfTwo(source.BlockBytes)) return error.InvalidVolumeHeader;
    const sectors = std.math.add(u64, last_lba - first_lba, 1) catch return error.InvalidVolumeHeader;
    if (scratch.len < source.BlockBytes) return error.BufferTooSmall;
    const first = scratch[0..source.BlockBytes];
    source.Read(source.Context, first_lba, first) catch return error.ReadFailed;
    const header = @as(*align(1) const VolumeHeader, @ptrCast(first.ptr)).*;
    if (!header.isValid() or !std.math.isPowerOfTwo(header.CellSize) or header.CellSize % source.BlockBytes != 0 or
        header.TotalCells == 0 or header.TotalCells > sectors / (header.CellSize / source.BlockBytes)) return error.InvalidVolumeHeader;
    return .{
        .Source = source,
        .FirstLBA = first_lba,
        .LastLBA = last_lba,
        .CellSize = header.CellSize,
        .TotalCells = header.TotalCells,
    };
}

pub fn reader(volume: *SectorVolume) BlockReader {
    return .{ .Context = volume, .ReadFn = readCell, .CellSize = volume.CellSize, .TotalCells = volume.TotalCells };
}

fn readCell(context: *anyopaque, cell: u64, output: []u8) BlockError!void {
    const volume: *const SectorVolume = @ptrCast(@alignCast(context));
    const size = volume.Source.BlockBytes;
    if (size == 0 or output.len != volume.CellSize or output.len == 0 or output.len % size != 0) return error.InvalidCell;
    if (cell >= volume.TotalCells) return error.OutOfBounds;
    const count = output.len / size;
    const displacement = std.math.mul(u64, cell, count) catch return error.OutOfBounds;
    const start = std.math.add(u64, volume.FirstLBA, displacement) catch return error.OutOfBounds;
    if (start > volume.LastLBA or count - 1 > volume.LastLBA - start) return error.OutOfBounds;
    for (0..count) |index| {
        const offset = index * size;
        volume.Source.Read(volume.Source.Context, start + index, output[offset..][0..size]) catch return error.ReadFailed;
    }
}
