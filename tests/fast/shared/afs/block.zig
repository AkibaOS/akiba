//! AFS Block Interface Checks

const std = @import("std");

const block = @import("shared").afs.types.block;
const constants = @import("tests").constants.storage;
const device = @import("tests").fast.shared.afs.device;
const errors = @import("shared").afs.errors.block;
const fixtures = @import("tests").types.storage;

pub fn singleCellCallbacks() !void {
    var storage = device.create();
    const interface = block.BlockDevice{ .Reader = device.createReader(&storage), .Writer = device.createWriter(&storage) };
    var output = [_]u8{constants.GUARD_BYTE} ** (constants.CELL_SIZE + constants.GUARD_BYTES);
    try interface.readCell(2, &output);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x33} ** constants.CELL_SIZE), output[0..constants.CELL_SIZE]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), output[constants.CELL_SIZE..]);
    try std.testing.expectEqual(@as(usize, 1), storage.ReadCount);
    try std.testing.expectEqualDeep(fixtures.Transfer{ .Cell = 2, .Length = constants.CELL_SIZE }, storage.Reads[0]);

    const input = [_]u8{0x9b} ** (constants.CELL_SIZE + constants.GUARD_BYTES);
    var expected = storage.Bytes;
    @memset(expected[constants.DEVICE_BYTES - constants.CELL_SIZE ..], 0x9b);
    try interface.writeCell(constants.TOTAL_CELLS - 1, &input);
    try std.testing.expectEqualSlices(u8, &expected, &storage.Bytes);
    try std.testing.expectEqual(@as(usize, 1), storage.WriteCount);
    try std.testing.expectEqualDeep(fixtures.Transfer{ .Cell = 7, .Length = constants.CELL_SIZE }, storage.Writes[0]);
}

pub fn multiCellCallbacks() !void {
    var storage = device.create();
    const reader = device.createReader(&storage);
    const writer = device.createWriter(&storage);
    var output: [2 * constants.CELL_SIZE]u8 = undefined;
    try reader.readCells(6, &output);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x77} ** constants.CELL_SIZE ++ [_]u8{0x88} ** constants.CELL_SIZE), &output);
    try std.testing.expectEqual(@as(usize, 2), storage.ReadCount);
    try std.testing.expectEqualDeep([_]fixtures.Transfer{
        .{ .Cell = 6, .Length = constants.CELL_SIZE },
        .{ .Cell = 7, .Length = constants.CELL_SIZE },
    }, storage.Reads[0..2].*);

    const input = [_]u8{0x91} ** constants.CELL_SIZE ++ [_]u8{0x92} ** constants.CELL_SIZE;
    var expected = storage.Bytes;
    @memset(expected[constants.CELL_SIZE..][0..constants.CELL_SIZE], 0x91);
    @memset(expected[2 * constants.CELL_SIZE ..][0..constants.CELL_SIZE], 0x92);
    try writer.writeCells(1, &input);
    try std.testing.expectEqualSlices(u8, &expected, &storage.Bytes);
    try std.testing.expectEqual(@as(usize, 2), storage.WriteCount);
    try std.testing.expectEqualDeep([_]fixtures.Transfer{
        .{ .Cell = 1, .Length = constants.CELL_SIZE },
        .{ .Cell = 2, .Length = constants.CELL_SIZE },
    }, storage.Writes[0..2].*);
    try reader.readCells(1, &output);
    try std.testing.expectEqualSlices(u8, &input, &output);
}

pub fn rejectedRequests() !void {
    var storage = device.create();
    var reader = device.createReader(&storage);
    var writer = device.createWriter(&storage);
    const original = storage.Bytes;
    var buffer = [_]u8{constants.GUARD_BYTE} ** (2 * constants.CELL_SIZE);

    try std.testing.expectError(errors.BlockError.OutOfBounds, reader.readCell(constants.TOTAL_CELLS, &buffer));
    try std.testing.expectError(errors.BlockError.OutOfBounds, writer.writeCell(constants.TOTAL_CELLS, &buffer));
    try std.testing.expectError(errors.BlockError.InvalidCell, reader.readCell(0, buffer[0 .. constants.CELL_SIZE - 1]));
    try std.testing.expectError(errors.BlockError.InvalidCell, writer.writeCell(0, buffer[0 .. constants.CELL_SIZE - 1]));
    try std.testing.expectError(errors.BlockError.InvalidCell, reader.readCells(0, buffer[0 .. constants.CELL_SIZE + 1]));
    try std.testing.expectError(errors.BlockError.InvalidCell, writer.writeCells(0, buffer[0 .. constants.CELL_SIZE + 1]));
    try std.testing.expectError(errors.BlockError.OutOfBounds, reader.readCells(7, &buffer));
    try std.testing.expectError(errors.BlockError.OutOfBounds, writer.writeCells(7, &buffer));
    try std.testing.expectError(errors.BlockError.OutOfBounds, reader.readCells(std.math.maxInt(u64), &buffer));
    try std.testing.expectError(errors.BlockError.OutOfBounds, writer.writeCells(std.math.maxInt(u64), &buffer));

    reader.CellSize = 0;
    writer.CellSize = 0;
    try std.testing.expectError(errors.BlockError.InvalidCell, reader.readCell(0, &buffer));
    try std.testing.expectError(errors.BlockError.InvalidCell, writer.writeCell(0, &buffer));
    try std.testing.expectError(errors.BlockError.InvalidCell, reader.readCells(0, buffer[0..0]));
    try std.testing.expectError(errors.BlockError.InvalidCell, writer.writeCells(0, buffer[0..0]));
    try std.testing.expectEqual(@as(usize, 0), storage.ReadCount);
    try std.testing.expectEqual(@as(usize, 0), storage.WriteCount);
    try std.testing.expectEqualSlices(u8, &original, &storage.Bytes);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** buffer.len), &buffer);
}

pub fn emptyRequests() !void {
    var storage = device.create();
    var reader = device.createReader(&storage);
    var writer = device.createWriter(&storage);
    var empty = [_]u8{};
    try reader.readCells(0, &empty);
    try writer.writeCells(constants.TOTAL_CELLS, &empty);
    try reader.readCells(constants.TOTAL_CELLS, &empty);
    try std.testing.expectError(errors.BlockError.OutOfBounds, reader.readCells(constants.TOTAL_CELLS + 1, &empty));
    try std.testing.expectError(errors.BlockError.OutOfBounds, writer.writeCells(constants.TOTAL_CELLS + 1, &empty));
    reader.TotalCells = 0;
    writer.TotalCells = 0;
    try reader.readCells(0, &empty);
    try writer.writeCells(0, &empty);
    try std.testing.expectEqual(@as(usize, 0), storage.ReadCount);
    try std.testing.expectEqual(@as(usize, 0), storage.WriteCount);
}

pub fn readFailureStopsTransfers() !void {
    var storage = device.create();
    storage.FailureCell = 2;
    const reader = device.createReader(&storage);
    var output = [_]u8{constants.GUARD_BYTE} ** (3 * constants.CELL_SIZE);
    try std.testing.expectError(errors.BlockError.DeviceError, reader.readCells(1, &output));
    try std.testing.expectEqual(@as(usize, 2), storage.ReadCount);
    try std.testing.expectEqual(@as(u64, 1), storage.Reads[0].Cell);
    try std.testing.expectEqual(@as(u64, 2), storage.Reads[1].Cell);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x22} ** constants.CELL_SIZE), output[0..constants.CELL_SIZE]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** (2 * constants.CELL_SIZE)), output[constants.CELL_SIZE..]);
    try reader.readCell(2, output[constants.CELL_SIZE..]);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x33} ** constants.CELL_SIZE), output[constants.CELL_SIZE..][0..constants.CELL_SIZE]);
    try std.testing.expectEqual(@as(?u64, null), storage.FailureCell);
}

pub fn writeFailureStopsTransfers() !void {
    var storage = device.create();
    storage.FailureCell = 2;
    const writer = device.createWriter(&storage);
    const input = [_]u8{0x91} ** (3 * constants.CELL_SIZE);
    var expected = storage.Bytes;
    @memset(expected[constants.CELL_SIZE..][0..constants.CELL_SIZE], 0x91);
    try std.testing.expectError(errors.BlockError.DeviceError, writer.writeCells(1, &input));
    try std.testing.expectEqual(@as(usize, 2), storage.WriteCount);
    try std.testing.expectEqual(@as(u64, 1), storage.Writes[0].Cell);
    try std.testing.expectEqual(@as(u64, 2), storage.Writes[1].Cell);
    try std.testing.expectEqualSlices(u8, &expected, &storage.Bytes);
    try writer.writeCell(2, input[0..constants.CELL_SIZE]);
    @memset(expected[2 * constants.CELL_SIZE ..][0..constants.CELL_SIZE], 0x91);
    try std.testing.expectEqualSlices(u8, &expected, &storage.Bytes);
    try std.testing.expectEqual(@as(?u64, null), storage.FailureCell);
}
