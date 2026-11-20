//! AFS Span Write Checks

const std = @import("std");

const catalog = @import("shared").afs.types.catalog;
const constants = @import("tests").fast.constants.storage;
const device = @import("tests").fast.shared.afs.device;
const errors = @import("shared").afs.errors.write.transfers;
const operations = @import("shared").afs.write.unit;
const read = @import("shared").afs.read.unit;
const volume = @import("shared").afs.types.volume;

pub fn exactAndTruncatedWrites() !void {
    var storage = device.create();
    const writer = device.createWriter(&storage);
    const span = volume.SpanDescriptor{ .StartCell = 2, .CellCount = 1 };
    const input = [_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES ++ [_]u8{0x91} ** constants.CELL_SIZE ++ [_]u8{0x92} ** constants.CELL_SIZE ++ [_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES;
    const data = input[constants.GUARD_BYTES .. input.len - constants.GUARD_BYTES];
    var guarded = [_]u8{constants.GUARD_BYTE} ** (constants.CELL_SIZE + 2 * constants.GUARD_BYTES);
    const scratch = guarded[constants.GUARD_BYTES..][0..constants.CELL_SIZE];
    var expected = storage.Bytes;
    @memset(expected[2 * constants.CELL_SIZE ..][0..constants.CELL_SIZE], 0x91);
    try std.testing.expectEqual(@as(u64, constants.CELL_SIZE), try operations.writeSpan(&writer, &span, data, scratch));
    try std.testing.expectEqualSlices(u8, &expected, &storage.Bytes);
    try std.testing.expectEqual(@as(usize, 1), storage.WriteCount);
    try std.testing.expectEqual(@as(u64, 2), storage.Writes[0].Cell);
    try std.testing.expectEqual(@as(usize, constants.CELL_SIZE), storage.Writes[0].Length);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[0..constants.GUARD_BYTES]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[guarded.len - constants.GUARD_BYTES ..]);

    const last = volume.SpanDescriptor{ .StartCell = 7, .CellCount = 1 };
    try std.testing.expectEqual(@as(u64, constants.CELL_SIZE), try operations.writeSpan(&writer, &last, data[constants.CELL_SIZE..], scratch));
    @memset(expected[7 * constants.CELL_SIZE ..], 0x92);
    try std.testing.expectEqualSlices(u8, &expected, &storage.Bytes);
}

pub fn partialCellPadding() !void {
    var storage = device.create();
    const writer = device.createWriter(&storage);
    const reader = device.createReader(&storage);
    const span = volume.SpanDescriptor{ .StartCell = 1, .CellCount = 3 };
    const input = [_]u8{0x91} ** constants.CELL_SIZE ++ [_]u8{0x92} ** constants.PARTIAL_BYTES;
    var scratch = [_]u8{constants.SCRATCH_BYTE} ** constants.CELL_SIZE;
    var expected = storage.Bytes;
    @memset(expected[constants.CELL_SIZE..][0..constants.CELL_SIZE], 0x91);
    @memset(expected[2 * constants.CELL_SIZE ..][0..constants.PARTIAL_BYTES], 0x92);
    @memset(expected[2 * constants.CELL_SIZE + constants.PARTIAL_BYTES .. 3 * constants.CELL_SIZE], 0);
    try std.testing.expectEqual(@as(u64, input.len), try operations.writeSpan(&writer, &span, &input, &scratch));
    try std.testing.expectEqualSlices(u8, &expected, &storage.Bytes);
    try std.testing.expectEqual(@as(usize, 2), storage.WriteCount);
    try std.testing.expectEqual(@as(u64, 1), storage.Writes[0].Cell);
    try std.testing.expectEqual(@as(u64, 2), storage.Writes[1].Cell);

    var output = [_]u8{constants.GUARD_BYTE} ** (2 * constants.CELL_SIZE + constants.GUARD_BYTES);
    const written = volume.SpanDescriptor{ .StartCell = 1, .CellCount = 2 };
    try std.testing.expectEqual(@as(u64, 2 * constants.CELL_SIZE), try read.readSpan(&reader, &written, &output, &scratch));
    try std.testing.expectEqualSlices(u8, &(input ++ [_]u8{0} ** (constants.CELL_SIZE - constants.PARTIAL_BYTES)), output[0 .. 2 * constants.CELL_SIZE]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), output[2 * constants.CELL_SIZE ..]);
}

pub fn fragmentedWriteRoundtrip() !void {
    var storage = device.create();
    const writer = device.createWriter(&storage);
    const reader = device.createReader(&storage);
    const input = [_]u8{0x91} ** constants.CELL_SIZE ++ [_]u8{0x92} ** constants.CELL_SIZE ++ [_]u8{0x93} ** constants.PARTIAL_BYTES;
    const first = volume.SpanDescriptor{ .StartCell = 5, .CellCount = 1 };
    const second = volume.SpanDescriptor{ .StartCell = 1, .CellCount = 2 };
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    try std.testing.expectEqual(@as(u64, constants.CELL_SIZE), try operations.writeSpan(&writer, &first, input[0..constants.CELL_SIZE], &scratch));
    try std.testing.expectEqual(@as(u64, constants.CELL_SIZE + constants.PARTIAL_BYTES), try operations.writeSpan(&writer, &second, input[constants.CELL_SIZE..], &scratch));
    var expected = device.create().Bytes;
    @memset(expected[5 * constants.CELL_SIZE ..][0..constants.CELL_SIZE], 0x91);
    @memset(expected[constants.CELL_SIZE..][0..constants.CELL_SIZE], 0x92);
    @memset(expected[2 * constants.CELL_SIZE ..][0..constants.PARTIAL_BYTES], 0x93);
    @memset(expected[2 * constants.CELL_SIZE + constants.PARTIAL_BYTES .. 3 * constants.CELL_SIZE], 0);
    try std.testing.expectEqualSlices(u8, &expected, &storage.Bytes);
    try std.testing.expectEqual(@as(usize, 3), storage.WriteCount);
    try std.testing.expectEqual(@as(u64, 5), storage.Writes[0].Cell);
    try std.testing.expectEqual(@as(u64, 1), storage.Writes[1].Cell);
    try std.testing.expectEqual(@as(u64, 2), storage.Writes[2].Cell);

    var unit = catalog.UnitRecord{};
    unit.DataChannel = .{ .LogicalSize = input.len, .PhysicalSize = 3 * constants.CELL_SIZE, .TotalCells = 3 };
    unit.DataChannel.Spans[0] = first;
    unit.DataChannel.Spans[1] = second;
    var output = [_]u8{constants.GUARD_BYTE} ** (input.len + constants.GUARD_BYTES);
    try std.testing.expectEqual(@as(u64, input.len), try read.readUnit(&reader, &unit, &output, &scratch));
    try std.testing.expectEqualSlices(u8, &input, output[0..input.len]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), output[input.len..]);
}

pub fn emptyWrites() !void {
    var storage = device.create();
    const writer = device.createWriter(&storage);
    const original = storage.Bytes;
    const span = volume.SpanDescriptor{ .StartCell = 1, .CellCount = 2 };
    var scratch = [_]u8{constants.SCRATCH_BYTE} ** constants.CELL_SIZE;
    try std.testing.expectEqual(@as(u64, 0), try operations.writeSpan(&writer, &span, &.{}, &scratch));
    try std.testing.expectEqual(@as(usize, 0), storage.WriteCount);
    try std.testing.expectEqualSlices(u8, &original, &storage.Bytes);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.SCRATCH_BYTE} ** constants.CELL_SIZE), &scratch);
}

pub fn writeFailureTranslation() !void {
    var storage = device.create();
    storage.FailureCell = 2;
    const writer = device.createWriter(&storage);
    const span = volume.SpanDescriptor{ .StartCell = 1, .CellCount = 3 };
    const input = [_]u8{0x91} ** (3 * constants.CELL_SIZE);
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    var expected = storage.Bytes;
    @memset(expected[constants.CELL_SIZE..][0..constants.CELL_SIZE], 0x91);
    try std.testing.expectError(errors.WriteError.WriteFailed, operations.writeSpan(&writer, &span, &input, &scratch));
    try std.testing.expectEqual(@as(usize, 2), storage.WriteCount);
    try std.testing.expectEqual(@as(u64, 1), storage.Writes[0].Cell);
    try std.testing.expectEqual(@as(u64, 2), storage.Writes[1].Cell);
    try std.testing.expectEqualSlices(u8, &expected, &storage.Bytes);
}
