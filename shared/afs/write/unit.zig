//! AFS Unit Write Operations

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");
const io = @import("../io/io.zig");

const BlockWriter = io.BlockWriter;
const BlockError = io.BlockError;
const SpanDescriptor = types.SpanDescriptor;
const ChannelInfo = types.ChannelInfo;

pub const WriteError = error{
    WriteFailed,
    OutOfSpace,
    InvalidCell,
};

pub fn write_span(
    writer: *const BlockWriter,
    span: *const SpanDescriptor,
    data: []const u8,
    cell_buffer: []u8,
) WriteError!u64 {
    const span_bytes = span.byte_size(writer.cell_size);
    const bytes_to_write = if (data.len < span_bytes) data.len else span_bytes;

    var bytes_written: u64 = 0;
    var current_cell = span.start_cell;

    while (bytes_written < bytes_to_write) {
        for (cell_buffer) |*b| {
            b.* = 0;
        }

        const bytes_remaining = bytes_to_write - bytes_written;
        const bytes_to_copy = if (bytes_remaining < writer.cell_size) bytes_remaining else writer.cell_size;

        var i: u64 = 0;
        while (i < bytes_to_copy) : (i += 1) {
            cell_buffer[@intCast(i)] = data[@intCast(bytes_written + i)];
        }

        writer.write_cell(current_cell, cell_buffer) catch {
            return WriteError.WriteFailed;
        };

        bytes_written += bytes_to_copy;
        current_cell += 1;
    }

    return bytes_written;
}

pub fn cells_needed(size: u64, cell_size: u32) u32 {
    if (size == 0) return 0;
    return @intCast((size + cell_size - 1) / cell_size);
}

pub fn create_channel_info(
    logical_size: u64,
    start_cell: u64,
    cell_count: u64,
    cell_size: u32,
) ChannelInfo {
    var channel = ChannelInfo{
        .logical_size = logical_size,
        .physical_size = cell_count * cell_size,
        .clump_size = cell_size,
        .total_cells = @intCast(cell_count),
        .spans = [_]types.SpanDescriptor{.{}} ** constants.span_inline_count,
    };

    if (cell_count > 0) {
        channel.spans[0] = .{
            .start_cell = start_cell,
            .cell_count = cell_count,
        };
    }

    return channel;
}
