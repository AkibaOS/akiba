//! AFS Span And Unit Read Checks

const std = @import("std");

const catalog = @import("shared").afs.types.catalog;
const constants = @import("tests").fast.constants.storage;
const device = @import("tests").fast.afs.device;
const errors = @import("shared").afs.errors.read.transfers;
const operations = @import("shared").afs.read.unit;
const range = @import("shared").afs.read.range;
const volume = @import("shared").afs.types.volume;

pub fn exactAndPartialSpans() !void {
    var storage = device.create();
    const reader = device.createReader(&storage);
    const span = volume.SpanDescriptor{ .StartCell = 2, .CellCount = 2 };
    var scratch = [_]u8{constants.SCRATCH_BYTE} ** constants.CELL_SIZE;
    var output = [_]u8{constants.GUARD_BYTE} ** (3 * constants.CELL_SIZE);
    try std.testing.expectEqual(@as(u64, 2 * constants.CELL_SIZE), try operations.readSpan(&reader, &span, &output, &scratch));
    try std.testing.expectEqualSlices(u8, &([_]u8{0x33} ** constants.CELL_SIZE ++ [_]u8{0x44} ** constants.CELL_SIZE), output[0 .. 2 * constants.CELL_SIZE]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.CELL_SIZE), output[2 * constants.CELL_SIZE ..]);

    var guarded = [_]u8{constants.GUARD_BYTE} ** (2 * constants.GUARD_BYTES + constants.CELL_SIZE + constants.PARTIAL_BYTES);
    const destination = guarded[constants.GUARD_BYTES..][0 .. constants.CELL_SIZE + constants.PARTIAL_BYTES];
    try std.testing.expectEqual(@as(u64, destination.len), try operations.readSpan(&reader, &span, destination, &scratch));
    try std.testing.expectEqualSlices(u8, &([_]u8{0x33} ** constants.CELL_SIZE ++ [_]u8{0x44} ** constants.PARTIAL_BYTES), destination);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[0..constants.GUARD_BYTES]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[guarded.len - constants.GUARD_BYTES ..]);
    try std.testing.expectEqual(@as(usize, 4), storage.ReadCount);
    try std.testing.expectEqual(@as(u64, 0), try operations.readSpan(&reader, &span, destination[0..0], &scratch));
    try std.testing.expectEqual(@as(usize, 4), storage.ReadCount);
}

pub fn rejectedSpanReads() !void {
    var storage = device.create();
    var reader = device.createReader(&storage);
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    var output = [_]u8{constants.GUARD_BYTE} ** constants.CELL_SIZE;
    const valid = volume.SpanDescriptor{ .StartCell = 1, .CellCount = 1 };
    try std.testing.expectError(errors.ReadError.BufferTooSmall, operations.readSpan(&reader, &valid, &output, scratch[0 .. constants.CELL_SIZE - 1]));
    reader.CellSize = 0;
    try std.testing.expectError(errors.ReadError.BufferTooSmall, operations.readSpan(&reader, &valid, &output, &scratch));
    reader.CellSize = constants.CELL_SIZE;
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readSpan(&reader, &.{}, &output, &scratch));
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readSpan(&reader, &.{ .StartCell = 7, .CellCount = 2 }, &output, &scratch));
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readSpan(&reader, &.{ .StartCell = 8, .CellCount = 1 }, &output, &scratch));
    reader.TotalCells = std.math.maxInt(u64);
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readSpan(&reader, &.{ .StartCell = 0, .CellCount = std.math.maxInt(u64) }, &output, &scratch));
    try std.testing.expectEqual(@as(usize, 0), storage.ReadCount);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.CELL_SIZE), &output);
}

pub fn fragmentedUnitReads() !void {
    var storage = device.create();
    const reader = device.createReader(&storage);
    var unit = catalog.UnitRecord{};
    unit.DataChannel.LogicalSize = 2 * constants.CELL_SIZE + constants.PARTIAL_BYTES;
    unit.DataChannel.PhysicalSize = 3 * constants.CELL_SIZE;
    unit.DataChannel.TotalCells = 3;
    unit.DataChannel.Spans[0] = .{ .StartCell = 5, .CellCount = 1 };
    unit.DataChannel.Spans[1] = .{ .StartCell = 1, .CellCount = 2 };
    unit.ResourceChannel.LogicalSize = constants.CELL_SIZE;
    unit.ResourceChannel.PhysicalSize = constants.CELL_SIZE;
    unit.ResourceChannel.TotalCells = 1;
    unit.ResourceChannel.Spans[0] = .{ .StartCell = 7, .CellCount = 1 };
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    var guarded = [_]u8{constants.GUARD_BYTE} ** (2 * constants.GUARD_BYTES + 2 * constants.CELL_SIZE + constants.PARTIAL_BYTES);
    const destination = guarded[constants.GUARD_BYTES..][0 .. 2 * constants.CELL_SIZE + constants.PARTIAL_BYTES];
    try std.testing.expectEqual(@as(u64, destination.len), try operations.readUnit(&reader, &unit, destination, &scratch));
    try std.testing.expectEqualSlices(u8, &([_]u8{0x66} ** constants.CELL_SIZE ++ [_]u8{0x22} ** constants.CELL_SIZE ++ [_]u8{0x33} ** constants.PARTIAL_BYTES), destination);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[0..constants.GUARD_BYTES]);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), guarded[guarded.len - constants.GUARD_BYTES ..]);
    try std.testing.expectEqual(@as(usize, 3), storage.ReadCount);
    try std.testing.expectEqual(@as(u64, 5), storage.Reads[0].Cell);
    try std.testing.expectEqual(@as(u64, 1), storage.Reads[1].Cell);
    try std.testing.expectEqual(@as(u64, 2), storage.Reads[2].Cell);
}

pub fn fragmentedRanges() !void {
    var storage = device.create();
    const reader = device.createReader(&storage);
    var unit = catalog.UnitRecord{};
    unit.DataChannel.LogicalSize = constants.CELL_SIZE + constants.PARTIAL_BYTES;
    unit.DataChannel.PhysicalSize = 2 * constants.CELL_SIZE;
    unit.DataChannel.TotalCells = 2;
    unit.DataChannel.Spans[0] = .{ .StartCell = 5, .CellCount = 1 };
    unit.DataChannel.Spans[1] = .{ .StartCell = 1, .CellCount = 1 };
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    var guarded = [_]u8{constants.GUARD_BYTE} ** (3 * constants.PARTIAL_BYTES);
    const offset = constants.CELL_SIZE - constants.PARTIAL_BYTES;
    try std.testing.expectEqual(@as(usize, 2 * constants.PARTIAL_BYTES), try range.unit(&reader, &unit, offset, &guarded, &scratch));
    try std.testing.expectEqualSlices(u8, &([_]u8{0x66} ** constants.PARTIAL_BYTES ++ [_]u8{0x22} ** constants.PARTIAL_BYTES ++ [_]u8{constants.GUARD_BYTE} ** constants.PARTIAL_BYTES), &guarded);
    try std.testing.expectEqual(@as(usize, 2), storage.ReadCount);
    try std.testing.expectEqual(@as(u64, 5), storage.Reads[0].Cell);
    try std.testing.expectEqual(@as(u64, 1), storage.Reads[1].Cell);
    try std.testing.expectEqual(@as(usize, 0), try range.unit(&reader, &unit, unit.DataChannel.LogicalSize, &guarded, &scratch));
    try std.testing.expectError(error.InvalidOffset, range.unit(&reader, &unit, unit.DataChannel.LogicalSize + 1, &guarded, &scratch));
    unit.DataChannel.Spans[1] = .{};
    try std.testing.expectError(error.InvalidSpan, range.unit(&reader, &unit, 0, &guarded, &scratch));
    try std.testing.expectEqual(@as(usize, 2), storage.ReadCount);
}

pub fn incompleteInlineChannels() !void {
    var storage = device.create();
    const reader = device.createReader(&storage);
    var unit = catalog.UnitRecord{};
    unit.DataChannel.LogicalSize = 2 * constants.CELL_SIZE;
    unit.DataChannel.PhysicalSize = 2 * constants.CELL_SIZE;
    unit.DataChannel.TotalCells = 2;
    unit.DataChannel.Spans[0] = .{ .StartCell = 1, .CellCount = 1 };
    unit.DataChannel.Spans[2] = .{ .StartCell = 5, .CellCount = 1 };
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    var output = [_]u8{constants.GUARD_BYTE} ** (2 * constants.CELL_SIZE);
    try std.testing.expectEqual(@as(u64, constants.CELL_SIZE), try operations.readUnitInlineSpans(&reader, &unit.DataChannel, &output, &scratch));
    try std.testing.expectEqualSlices(u8, &([_]u8{0x22} ** constants.CELL_SIZE ++ [_]u8{constants.GUARD_BYTE} ** constants.CELL_SIZE), &output);
    try std.testing.expectEqual(@as(usize, 1), storage.ReadCount);
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readUnit(&reader, &unit, &output, &scratch));
    try std.testing.expectEqual(@as(usize, 2), storage.ReadCount);
}

pub fn rejectedChannelReads() !void {
    var storage = device.create();
    var reader = device.createReader(&storage);
    var channel = volume.ChannelInfo{ .LogicalSize = constants.CELL_SIZE, .PhysicalSize = constants.CELL_SIZE, .TotalCells = 1 };
    channel.Spans[0] = .{ .StartCell = 1, .CellCount = 1 };
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    var output = [_]u8{constants.GUARD_BYTE} ** constants.CELL_SIZE;
    try std.testing.expectError(errors.ReadError.BufferTooSmall, operations.readUnitInlineSpans(&reader, &channel, output[0 .. constants.CELL_SIZE - 1], &scratch));
    try std.testing.expectError(errors.ReadError.BufferTooSmall, operations.readUnitInlineSpans(&reader, &channel, &output, scratch[0 .. constants.CELL_SIZE - 1]));
    reader.CellSize = 0;
    try std.testing.expectError(errors.ReadError.BufferTooSmall, operations.readUnitInlineSpans(&reader, &channel, &output, &scratch));
    reader.CellSize = constants.CELL_SIZE;
    channel.LogicalSize += 1;
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readUnitInlineSpans(&reader, &channel, &output, &scratch));
    channel.LogicalSize = 1;
    channel.PhysicalSize += 1;
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readUnitInlineSpans(&reader, &channel, &output, &scratch));
    channel.PhysicalSize = constants.CELL_SIZE;
    channel.TotalCells = @intCast(constants.TOTAL_CELLS + 1);
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readUnitInlineSpans(&reader, &channel, &output, &scratch));
    channel.TotalCells = 1;
    channel.Spans[0] = .{ .StartCell = constants.TOTAL_CELLS, .CellCount = 1 };
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readUnitInlineSpans(&reader, &channel, &output, &scratch));
    channel.Spans[0] = .{ .StartCell = 1, .CellCount = 2 };
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readUnitInlineSpans(&reader, &channel, &output, &scratch));
    try std.testing.expectEqual(@as(usize, 0), storage.ReadCount);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.CELL_SIZE), &output);
}

pub fn cumulativeSpanAccounting() !void {
    var storage = device.create();
    const reader = device.createReader(&storage);
    var channel = volume.ChannelInfo{ .LogicalSize = 2 * constants.CELL_SIZE, .PhysicalSize = 2 * constants.CELL_SIZE, .TotalCells = 2 };
    channel.Spans[0] = .{ .StartCell = 1, .CellCount = 1 };
    channel.Spans[1] = .{ .StartCell = 3, .CellCount = 2 };
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    var output = [_]u8{constants.GUARD_BYTE} ** (2 * constants.CELL_SIZE);
    try std.testing.expectError(errors.ReadError.InvalidSpan, operations.readUnitInlineSpans(&reader, &channel, &output, &scratch));
    try std.testing.expectEqual(@as(usize, 1), storage.ReadCount);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x22} ** constants.CELL_SIZE ++ [_]u8{constants.GUARD_BYTE} ** constants.CELL_SIZE), &output);
}

pub fn emptyUnitReads() !void {
    var storage = device.create();
    const reader = device.createReader(&storage);
    const unit = catalog.UnitRecord{};
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    var output = [_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES;
    try std.testing.expectEqual(@as(u64, 0), try operations.readUnit(&reader, &unit, &output, &scratch));
    try std.testing.expectEqual(@as(u64, 0), try operations.readUnit(&reader, &unit, output[0..0], &scratch));
    try std.testing.expectEqual(@as(usize, 0), storage.ReadCount);
    try std.testing.expectEqualSlices(u8, &([_]u8{constants.GUARD_BYTE} ** constants.GUARD_BYTES), &output);
}

pub fn readFailureTranslation() !void {
    var storage = device.create();
    storage.FailureCell = 2;
    const reader = device.createReader(&storage);
    const span = volume.SpanDescriptor{ .StartCell = 1, .CellCount = 3 };
    var scratch: [constants.CELL_SIZE]u8 = undefined;
    var output = [_]u8{constants.GUARD_BYTE} ** (3 * constants.CELL_SIZE);
    try std.testing.expectError(errors.ReadError.ReadFailed, operations.readSpan(&reader, &span, &output, &scratch));
    try std.testing.expectEqual(@as(usize, 2), storage.ReadCount);
    try std.testing.expectEqual(@as(u64, 1), storage.Reads[0].Cell);
    try std.testing.expectEqual(@as(u64, 2), storage.Reads[1].Cell);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x22} ** constants.CELL_SIZE ++ [_]u8{constants.GUARD_BYTE} ** (2 * constants.CELL_SIZE)), &output);
}
