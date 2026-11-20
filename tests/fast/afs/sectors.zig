//! Bounded Sector Backed AFS Cell Reads

const std = @import("std");

const sectors = @import("shared").afs.read.sectors;
const values = @import("tests").fast.constants.afs.sectors;

const Source = @import("shared").storage.types.sector.Source;
const Trace = @import("tests").fast.types.afs.sectors.Trace;

pub fn exactWindow() !void {
    var trace: Trace = .{};
    var first: [values.BLOCK_BYTES]u8 = undefined;
    var volume = try sectors.open(source(&trace), values.FIRST, values.LAST, &first);
    const reader = sectors.reader(&volume);
    try std.testing.expectEqual(@as(u32, values.CELL_BYTES), reader.CellSize);
    try std.testing.expectEqual(@as(u64, values.CELLS), reader.TotalCells);
    var cell: [values.CELL_BYTES]u8 = undefined;
    try reader.readCell(values.CELLS - 1, &cell);
    try std.testing.expect(std.mem.allEqual(u8, cell[0..values.BLOCK_BYTES], @truncate(values.LAST - 1)));
    try std.testing.expect(std.mem.allEqual(u8, cell[values.BLOCK_BYTES..], @truncate(values.LAST)));
    try std.testing.expectError(error.OutOfBounds, reader.readCell(values.CELLS, &cell));
    try std.testing.expectEqualSlices(u64, &.{ values.FIRST, values.LAST - 1, values.LAST }, trace.Reads[0..trace.Count]);
}

pub fn rejectsInvalidGeometry() !void {
    var trace: Trace = .{};
    var first: [values.BLOCK_BYTES]u8 = undefined;
    try std.testing.expectError(error.InvalidVolumeHeader, sectors.open(source(&trace), values.FIRST, values.LAST - 1, &first));
    try std.testing.expectEqualSlices(u64, &.{values.FIRST}, trace.Reads[0..trace.Count]);
    trace.Count = 0;
    trace.Header.CellSize = values.FRACTIONAL_CELL_BYTES;
    try std.testing.expectError(error.InvalidVolumeHeader, sectors.open(source(&trace), values.FIRST, values.LAST, &first));
    try std.testing.expectEqualSlices(u64, &.{values.FIRST}, trace.Reads[0..trace.Count]);
    trace.Count = 0;
    try std.testing.expectError(error.InvalidVolumeHeader, sectors.open(source(&trace), values.FIRST, values.DISK_LAST + 1, &first));
    try std.testing.expectError(error.BufferTooSmall, sectors.open(source(&trace), values.FIRST, values.LAST, first[0 .. first.len - 1]));
    try std.testing.expectEqual(@as(usize, 0), trace.Count);
}

pub fn lateReadFailure() !void {
    var trace: Trace = .{ .FailAt = values.LAST };
    var first: [values.BLOCK_BYTES]u8 = undefined;
    var volume = try sectors.open(source(&trace), values.FIRST, values.LAST, &first);
    const reader = sectors.reader(&volume);
    var cell: [values.CELL_BYTES]u8 = undefined;
    try std.testing.expectError(error.ReadFailed, reader.readCell(values.CELLS - 1, &cell));
    try std.testing.expectEqualSlices(u64, &.{ values.FIRST, values.LAST - 1, values.LAST }, trace.Reads[0..trace.Count]);
}

fn source(trace: *Trace) Source {
    return .{ .Context = trace, .Read = read, .BlockBytes = values.BLOCK_BYTES, .LastLBA = values.DISK_LAST };
}

fn read(context: *anyopaque, lba: u64, raw: []u8) !void {
    const trace: *Trace = @ptrCast(@alignCast(context));
    if (raw.len != values.BLOCK_BYTES or trace.Count >= trace.Reads.len) return error.TestUnexpectedResult;
    trace.Reads[trace.Count] = lba;
    trace.Count += 1;
    if (trace.FailAt == lba) return error.EndOfStream;
    @memset(raw, @truncate(lba));
    if (lba == values.FIRST) @memcpy(raw[0..@sizeOf(@TypeOf(trace.Header))], std.mem.asBytes(&trace.Header));
}
