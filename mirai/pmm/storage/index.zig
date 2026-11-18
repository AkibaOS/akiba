//! Sparse Frame Range Index And Ordered Traversal

const records = @import("mirai").pmm.storage.records;
const types = @import("mirai").pmm.types.storage;

pub fn balance(first: *?*types.Frame, count: u64) ?*types.Frame {
    if (count == 0) return null;
    const lower_count = count / 2;
    const lower = balance(first, lower_count);
    const middle = first.*.?;
    first.* = middle.Header.Next;
    middle.Header.Lower = lower;
    middle.Header.Higher = balance(first, count - lower_count - 1);
    return middle;
}

pub fn start(index: types.Index, page: u64) types.Walker {
    var current = index.Root;
    var following: ?*types.Frame = null;
    while (current) |frame| {
        if (page >= frame.Header.EndPage) {
            current = frame.Header.Higher;
        } else {
            following = frame;
            if (page >= frame.Header.FirstPage) break;
            current = frame.Header.Lower;
        }
    }
    return .{ .Frame = following };
}

pub fn next(walker: *types.Walker) ?types.View {
    const frame = walker.Frame orelse return null;
    const record = records.view(frame, walker.Offset);
    walker.Offset += records.stride(record.Range.End - record.Range.Start);
    if (walker.Offset == frame.Header.UsedBytes) {
        walker.Frame = frame.Header.Next;
        walker.Offset = 0;
    }
    return record;
}
