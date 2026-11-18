//! Physical First-Fit Search Across Sparse Records

const ranges = @import("mirai").pmm.storage.index;
const roles = @import("mirai").pmm.storage.roles;
const types = @import("mirai").pmm.types.storage;

pub fn find(index: types.Index, start: u64, end: u64, count: u64, alignment: u64) ?u64 {
    const limit = @min(end, index.PhysicalPages);
    if (count == 0 or alignment == 0 or start >= limit or count > limit - start) return null;
    var walker = ranges.start(index, start);
    const last_start = limit - count;
    var pending: ?u64 = null;
    var checked_end: u64 = start;
    while (ranges.next(&walker)) |view| {
        if (view.Range.Start >= limit) break;
        const stop = @min(limit, view.Range.End);
        var page = @max(start, view.Range.Start);
        if (page != checked_end) pending = null;
        while (page < stop) {
            const candidate = pending orelse (alignedAtOrAfter(page, last_start, alignment) orelse return null);
            if (candidate >= stop) break;
            const begin = @max(page, candidate);
            const free_start = roles.nextFree(view, begin, stop) orelse {
                pending = null;
                break;
            };
            if (free_start != begin) {
                pending = null;
                page = free_start;
                continue;
            }
            const required_end = candidate + count;
            checked_end = roles.freeEnd(view, begin, @min(stop, required_end));
            if (checked_end == required_end) return candidate;
            pending = if (checked_end == stop) candidate else null;
            page = checked_end;
        }
    }
    return null;
}

fn alignedAtOrAfter(start: u64, last: u64, alignment: u64) ?u64 {
    if (start > last) return null;
    const remainder = start % alignment;
    const padding = if (remainder == 0) 0 else alignment - remainder;
    return if (padding <= last - start) start + padding else null;
}
