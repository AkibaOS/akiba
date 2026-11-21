//! Read A Bounded Range Of An AFS Unit Data Channel

const bounds = @import("shared").afs.read.bounds;
const layout = @import("shared").afs.constants.sizes;
const units = @import("shared").afs.read.unit;

const BlockReader = @import("shared").afs.types.block.BlockReader;
const ChannelInfo = @import("shared").afs.types.volume.ChannelInfo;
const ReadError = @import("shared").afs.errors.read.transfers.ReadError;
const SpanDescriptor = @import("shared").afs.types.volume.SpanDescriptor;
const UnitRecord = @import("shared").afs.types.catalog.UnitRecord;

pub fn unit(reader: *const BlockReader, record: *const UnitRecord, offset: u64, output: []u8, scratch: []u8) ReadError!usize {
    if (reader.CellSize == 0 or scratch.len < reader.CellSize) return ReadError.BufferTooSmall;
    const channel = &record.DataChannel;
    const logical_bytes = try units.size(reader, channel);
    if (offset > logical_bytes) return ReadError.InvalidOffset;
    const spans = try validateSpans(reader, channel, logical_bytes);
    const length: usize = @intCast(@min(output.len, logical_bytes - offset));
    var skip = offset;
    var remaining = logical_bytes;
    var written: usize = 0;
    for (channel.Spans[0..spans]) |span| {
        if (written == length) break;
        const span_bytes = @min(remaining, span.byteSize(reader.CellSize));
        remaining -= span_bytes;
        if (skip >= span_bytes) {
            skip -= span_bytes;
            continue;
        }
        const count: usize = @intCast(@min(length - written, span_bytes - skip));
        try readWithin(reader, span, skip, output[written..][0..count], scratch);
        written += count;
        skip = 0;
    }
    return written;
}

fn validateSpans(reader: *const BlockReader, channel: *const ChannelInfo, logical_bytes: u64) ReadError!usize {
    var remaining = logical_bytes;
    var used: u64 = 0;
    var index: usize = 0;
    while (remaining != 0 and index < layout.SPAN_INLINE_COUNT) : (index += 1) {
        const span = channel.getSpan(index) orelse return ReadError.InvalidSpan;
        if (!bounds.spanFits(span.*, reader.TotalCells) or span.CellCount > channel.TotalCells - used) return ReadError.InvalidSpan;
        used += span.CellCount;
        remaining -= @min(remaining, span.byteSize(reader.CellSize));
    }
    if (remaining != 0) return ReadError.InvalidSpan;
    return index;
}

fn readWithin(reader: *const BlockReader, span: SpanDescriptor, offset: u64, output: []u8, scratch: []u8) ReadError!void {
    var cell = span.StartCell + offset / reader.CellSize;
    var start: usize = @intCast(offset % reader.CellSize);
    var written: usize = 0;
    while (written < output.len) : (cell += 1) {
        reader.readCell(cell, scratch) catch return ReadError.ReadFailed;
        const count = @min(output.len - written, reader.CellSize - start);
        @memcpy(output[written..][0..count], scratch[start..][0..count]);
        written += count;
        start = 0;
    }
}
