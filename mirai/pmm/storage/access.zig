//! Sparse Physical Page Role Access

const ranges = @import("mirai").pmm.storage.index;
const roles = @import("mirai").pmm.storage.roles;
const types = @import("mirai").pmm.types.storage.layout;

pub fn read(index: types.Index, page: u64) types.Role {
    var walker = ranges.start(index, page);
    while (ranges.next(&walker)) |view| {
        if (page < view.Range.Start) break;
        if (page < view.Range.End) return roles.read(view, page);
    }
    return .Hole;
}

pub fn matches(index: types.Index, start: u64, end: u64, role: types.Role) bool {
    var walker = ranges.start(index, start);
    var page = start;
    while (page < end) {
        const view = ranges.next(&walker) orelse return false;
        if (page < view.Range.Start) return false;
        const stop = @min(view.Range.End, end);
        while (page < stop) : (page += 1) {
            if (roles.read(view, page) != role) return false;
        }
    }
    return true;
}

pub fn assign(index: types.Index, range: types.Range, role: types.Role) void {
    var walker = ranges.start(index, range.Start);
    while (ranges.next(&walker)) |view| {
        if (view.Range.Start >= range.End) break;
        const start = @max(range.Start, view.Range.Start);
        const end = @min(range.End, view.Range.End);
        if (start < end) roles.assign(view, start, end, role);
    }
}
