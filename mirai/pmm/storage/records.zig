//! Packed Physical Range Record Format

const geometry = @import("mirai").pmm.constants.storage.layout;
const types = @import("mirai").pmm.types.storage.layout;

pub fn mapBytes(page_count: u64) usize {
    return @intCast((page_count + geometry.PAGES_PER_BYTE - 1) / geometry.PAGES_PER_BYTE);
}

pub fn stride(page_count: u64) usize {
    const unaligned = geometry.RECORD_HEADER_BYTES + mapBytes(page_count);
    return (unaligned + geometry.RECORD_ALIGNMENT - 1) & ~(geometry.RECORD_ALIGNMENT - 1);
}

pub fn at(frame: *types.Frame, offset: usize) *types.Record {
    return @ptrCast(@alignCast(&frame.Data[offset]));
}

pub fn view(frame: *types.Frame, offset: usize) types.View {
    const record = at(frame, offset);
    const data_start = offset + geometry.RECORD_HEADER_BYTES;
    return .{
        .Range = .{ .Start = record.StartPage, .End = record.StartPage + record.PageCount },
        .Map = frame.Data[data_start .. data_start + mapBytes(record.PageCount)],
    };
}
