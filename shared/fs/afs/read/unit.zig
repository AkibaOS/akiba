//! AFS Unit Read Operations

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");
const io = @import("../io/io.zig");

const BlockReader = io.BlockReader;
const BlockError = io.BlockError;
const SpanDescriptor = types.SpanDescriptor;
const ChannelInfo = types.ChannelInfo;
const UnitRecord = types.UnitRecord;

pub const ReadError = error{
    ReadFailed,
    UnitTooLarge,
    InvalidSpan,
    BufferTooSmall,
};

pub fn read_span(
    reader: *const BlockReader,
    span: *const SpanDescriptor,
    buffer: []u8,
    cell_buffer: []u8,
) ReadError!u64 {
    const span_bytes = span.byte_size(reader.cell_size);
    const bytes_to_read = if (buffer.len < span_bytes) buffer.len else span_bytes;

    var bytes_read: u64 = 0;
    var current_cell = span.start_cell;

    while (bytes_read < bytes_to_read) {
        reader.read_cell(current_cell, cell_buffer) catch {
            return ReadError.ReadFailed;
        };

        const bytes_remaining = bytes_to_read - bytes_read;
        const bytes_to_copy = if (bytes_remaining < reader.cell_size) bytes_remaining else reader.cell_size;

        var i: u64 = 0;
        while (i < bytes_to_copy) : (i += 1) {
            buffer[@intCast(bytes_read + i)] = cell_buffer[@intCast(i)];
        }

        bytes_read += bytes_to_copy;
        current_cell += 1;
    }

    return bytes_read;
}

pub fn read_unit_inline_spans(
    reader: *const BlockReader,
    channel: *const ChannelInfo,
    buffer: []u8,
    cell_buffer: []u8,
) ReadError!u64 {
    const unit_size = channel.logical_size;

    if (buffer.len < unit_size) {
        return ReadError.BufferTooSmall;
    }

    var bytes_read: u64 = 0;
    var span_index: usize = 0;

    while (bytes_read < unit_size and span_index < constants.span_inline_count) {
        const span = channel.get_span(span_index);
        if (span == null) {
            break;
        }

        const span_bytes = span.?.byte_size(reader.cell_size);
        const bytes_remaining = unit_size - bytes_read;
        const bytes_to_read = if (bytes_remaining < span_bytes) bytes_remaining else span_bytes;

        const dest_slice = buffer[@intCast(bytes_read)..@intCast(bytes_read + bytes_to_read)];
        _ = try read_span(reader, span.?, dest_slice, cell_buffer);

        bytes_read += bytes_to_read;
        span_index += 1;
    }

    return bytes_read;
}

pub fn read_unit(
    reader: *const BlockReader,
    unit: *const UnitRecord,
    buffer: []u8,
    cell_buffer: []u8,
) ReadError!u64 {
    return read_unit_inline_spans(reader, &unit.data_channel, buffer, cell_buffer);
}
