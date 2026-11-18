//! Checked Single Physical Page Release

const range = @import("mirai").pmm.free.range;

pub fn freePage(physical: u64) void {
    _ = releasePage(physical);
}

pub fn releasePage(physical: u64) bool {
    return range.releaseRange(physical, 1);
}
