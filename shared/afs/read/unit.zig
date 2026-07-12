//! AFS Unit Read Operations

const constants = @import("../constants/constants.zig");
const errors = @import("../errors/errors.zig");
const io = @import("../io/io.zig");
const types = @import("../types/types.zig");

const BlockReader = io.block.BlockReader;
const ChannelInfo = types.volume.ChannelInfo;
const ReadError = errors.read.ReadError;
const SpanDescriptor = types.volume.SpanDescriptor;
const UnitRecord = types.catalog.UnitRecord;

pub fn readSpan(
    reader: *const BlockReader,
    span: *const SpanDescriptor,
    buffer: []u8,
    cell_buffer: []u8,
) ReadError!u64 {
    const span_bytes = span.byteSize(reader.CellSize);
    const bytes_to_read = if (buffer.len < span_bytes) buffer.len else span_bytes;

    var bytes_read: u64 = 0;
    var current_cell = span.StartCell;

    while (bytes_read < bytes_to_read) {
        reader.readCell(current_cell, cell_buffer) catch {
            return ReadError.ReadFailed;
        };

        const bytes_remaining = bytes_to_read - bytes_read;
        const bytes_to_copy = if (bytes_remaining < reader.CellSize) bytes_remaining else reader.CellSize;

        var index: u64 = 0;
        while (index < bytes_to_copy) : (index += 1) {
            buffer[@intCast(bytes_read + index)] = cell_buffer[@intCast(index)];
        }

        bytes_read += bytes_to_copy;
        current_cell += 1;
    }

    return bytes_read;
}

pub fn readUnitInlineSpans(
    reader: *const BlockReader,
    channel: *const ChannelInfo,
    buffer: []u8,
    cell_buffer: []u8,
) ReadError!u64 {
    const unit_size = channel.LogicalSize;

    if (buffer.len < unit_size) {
        return ReadError.BufferTooSmall;
    }

    var bytes_read: u64 = 0;
    var span_index: usize = 0;

    while (bytes_read < unit_size and span_index < constants.sizes.SPAN_INLINE_COUNT) {
        const span = channel.getSpan(span_index);
        if (span == null) {
            break;
        }

        const span_bytes = span.?.byteSize(reader.CellSize);
        const bytes_remaining = unit_size - bytes_read;
        const bytes_to_read = if (bytes_remaining < span_bytes) bytes_remaining else span_bytes;

        const destination_slice = buffer[@intCast(bytes_read)..@intCast(bytes_read + bytes_to_read)];
        _ = try readSpan(reader, span.?, destination_slice, cell_buffer);

        bytes_read += bytes_to_read;
        span_index += 1;
    }

    return bytes_read;
}

pub fn readUnit(
    reader: *const BlockReader,
    unit: *const UnitRecord,
    buffer: []u8,
    cell_buffer: []u8,
) ReadError!u64 {
    return readUnitInlineSpans(reader, &unit.DataChannel, buffer, cell_buffer);
}
