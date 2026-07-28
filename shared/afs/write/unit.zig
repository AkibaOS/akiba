//! AFS Unit Write Operations

const constants = @import("shared").afs.constants;
const errors = @import("shared").afs.errors;
const io = @import("shared").afs.io;
const types = @import("shared").afs.types;

const math = @import("utils").math;

const BlockWriter = io.block.BlockWriter;
const ChannelInfo = types.volume.ChannelInfo;
const SpanDescriptor = types.volume.SpanDescriptor;
const WriteError = errors.write.WriteError;

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

pub fn cellsNeeded(size: u64, cell_size: u32) u32 {
    if (size == 0) return 0;
    return @intCast(math.integer.divideCeil(size, cell_size));
}

pub fn createChannelInfo(
    logical_size: u64,
    start_cell: u64,
    cell_count: u64,
    cell_size: u32,
) ChannelInfo {
    var channel = ChannelInfo{
        .LogicalSize = logical_size,
        .PhysicalSize = cell_count * cell_size,
        .ClumpSize = cell_size,
        .TotalCells = @intCast(cell_count),
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
