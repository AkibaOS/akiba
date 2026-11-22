//! AFS Unit Write Operations

const std = @import("std");

const constants = @import("shared").afs.constants;
const errors = @import("shared").afs.errors;
const math = @import("common").math;
const types = @import("shared").afs.types;

const BlockWriter = types.block.BlockWriter;
const ChannelInfo = types.volume.ChannelInfo;
const SpanDescriptor = types.volume.SpanDescriptor;
const WriteError = errors.write.transfers.WriteError;

pub fn writeSpan(
    writer: *const BlockWriter,
    span: *const SpanDescriptor,
    data: []const u8,
    cell_buffer: []u8,
) WriteError!u64 {
    const span_bytes = span.byteSize(writer.CellSize);
    const bytes_to_write = if (data.len < span_bytes) data.len else span_bytes;

    var bytes_written: u64 = 0;
    var current_cell = span.StartCell;

    while (bytes_written < bytes_to_write) {
        for (cell_buffer) |*cell_byte| {
            cell_byte.* = 0;
        }

        const bytes_remaining = bytes_to_write - bytes_written;
        const bytes_to_copy = if (bytes_remaining < writer.CellSize) bytes_remaining else writer.CellSize;

        var index: u64 = 0;
        while (index < bytes_to_copy) : (index += 1) {
            cell_buffer[@intCast(index)] = data[@intCast(bytes_written + index)];
        }

        writer.writeCell(current_cell, cell_buffer) catch {
            return WriteError.WriteFailed;
        };

        bytes_written += bytes_to_copy;
        current_cell += 1;
    }

    return bytes_written;
}

pub fn cellsNeeded(size: u64, cell_size: u32) WriteError!u32 {
    if (cell_size == 0) return WriteError.InvalidCell;
    if (size == 0) return 0;
    const cells = math.integer.divideCeil(size, cell_size);
    return std.math.cast(u32, cells) orelse return WriteError.Overflow;
}

pub fn createChannelInfo(
    logical_size: u64,
    start_cell: u64,
    cell_count: u64,
    cell_size: u32,
) WriteError!ChannelInfo {
    if (cell_size == 0) return WriteError.InvalidCell;
    const total_cells = std.math.cast(u32, cell_count) orelse return WriteError.Overflow;
    const physical_size = std.math.mul(u64, cell_count, cell_size) catch return WriteError.Overflow;
    if (logical_size > physical_size) return WriteError.InvalidSpan;
    if (cell_count > 0) _ = std.math.add(u64, start_cell, cell_count) catch return WriteError.Overflow;
    var channel = ChannelInfo{
        .LogicalSize = logical_size,
        .PhysicalSize = physical_size,
        .ClumpSize = cell_size,
        .TotalCells = total_cells,
        .Spans = [_]SpanDescriptor{.{}} ** constants.sizes.SPAN_INLINE_COUNT,
    };

    if (cell_count > 0) {
        channel.Spans[0] = .{
            .StartCell = start_cell,
            .CellCount = cell_count,
        };
    }

    return channel;
}
