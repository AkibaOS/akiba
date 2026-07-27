//! Extract Physical Address

const common = @import("common");

const tables = @import("../tables/tables.zig");
const types = @import("../types/types.zig");

const indices = common.constants.paging.indices;

const Kagami = types.kagami.Kagami;

pub fn extract(kagami: *const Kagami, virtual_address: u64) ?u64 {
    const entry = tables.walk.walkToEntry(kagami.PML4Physical, virtual_address) orelse return null;

    if (!entry.isPresent()) {
        return null;
    }

    const physical_base = entry.getPhysicalAddress();
    const offset = virtual_address & indices.OFFSET_MASK;

    return physical_base | offset;
}

pub fn isMapped(kagami: *const Kagami, virtual_address: u64) bool {
    const entry = tables.walk.walkToEntry(kagami.PML4Physical, virtual_address) orelse return false;
    return entry.isPresent();
}

pub fn isWritable(kagami: *const Kagami, virtual_address: u64) bool {
    const entry = tables.walk.walkToEntry(kagami.PML4Physical, virtual_address) orelse return false;
    return entry.isPresent() and entry.isWritable();
}

pub fn isUserAccessible(kagami: *const Kagami, virtual_address: u64) bool {
    const entry = tables.walk.walkToEntry(kagami.PML4Physical, virtual_address) orelse return false;
    return entry.isPresent() and entry.isUser();
}
