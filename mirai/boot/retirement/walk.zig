//! Inherited Table Graph Walk With An Explicit Ownership Check

const common = @import("common");
const retirement = @import("mirai").boot.types.retirement;

const flags = common.constants.paging.flags;
const indices = common.constants.paging.indices;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn exact(footprint: retirement.Footprint, limit: u64, context: anytype, comptime check: anytype) bool {
    const pages = limit / sizes.PAGE_SIZE;
    if (footprint.Root.Start >= pages or footprint.Tables.ChildFrames >= pages) return false;
    var remaining = footprint.Tables.ChildFrames + 1;
    return table(footprint.Root.Start, sizes.PAGE_TABLE_LEVELS, pages, &remaining, context, check) and remaining == 0;
}

fn table(page: u64, depth: u8, limit: u64, remaining: *u64, context: anytype, comptime check: anytype) bool {
    if (page == 0 or page >= limit or remaining.* == 0 or !check(context, page)) return false;
    remaining.* -= 1;
    if (depth == 1) return true;
    const entries: *const [sizes.ENTRIES_PER_PAGE_TABLE]u64 = @ptrFromInt(layout.PHYSMAP_BASE + page * sizes.PAGE_SIZE);
    for (entries) |entry| {
        if (entry & flags.PRESENT == 0) continue;
        if (entry & flags.HUGE_PAGE != 0) {
            if (depth == sizes.PAGE_TABLE_LEVELS) return false;
            continue;
        }
        if (!table((entry & indices.ADDRESS_MASK) / sizes.PAGE_SIZE, depth - 1, limit, remaining, context, check)) return false;
    }
    return true;
}
