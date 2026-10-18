//! Bounded Huge Aware Page Table Lookup

const common = @import("common");
const state = @import("mirai").kagami.state;
const types = @import("mirai").kagami.types;

const indices = common.constants.paging.indices;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const Entry = types.entry.Entry;
const Lookup = types.lookup.Lookup;
const Table = types.table.Table;

pub fn isCanonical(virtual_address: u64) bool {
    return virtual_address <= layout.USER_SPACE_END or virtual_address >= ~layout.USER_SPACE_END;
}

pub fn isValidTable(physical_address: u64) bool {
    const limit = state.getPolicy().PhysmapSize;
    return physical_address != 0 and (physical_address & sizes.PAGE_MASK) == 0 and
        physical_address < limit and sizes.PAGE_SIZE <= limit - physical_address;
}

pub fn getTableFromPhysical(physical_address: u64) *Table {
    return @ptrFromInt(layout.PHYSMAP_BASE + physical_address);
}

pub fn getPML4(pml4_physical: u64) *Table {
    return getTableFromPhysical(pml4_physical);
}

pub fn lookup(pml4_physical: u64, virtual_address: u64) ?Lookup {
    if (!isCanonical(virtual_address) or !isValidTable(pml4_physical)) return null;
    var physical_address = pml4_physical;
    var writable = true;
    var user_accessible = true;
    var executable = true;
    var visited: [sizes.PAGE_TABLE_LEVELS]u64 = undefined;
    const shifts = [_]u6{ indices.PML4_SHIFT, indices.PDPT_SHIFT, indices.PD_SHIFT, indices.PT_SHIFT };
    for (shifts, 0..) |shift, level| {
        for (visited[0..level]) |ancestor| {
            if (physical_address == ancestor) return null;
        }
        visited[level] = physical_address;
        if (!isValidTable(physical_address)) return null;
        const table = getTableFromPhysical(physical_address);
        const entry = &table.Entries[@intCast((virtual_address >> shift) & indices.INDEX_MASK)];
        if (!entry.Present or (shift == indices.PML4_SHIFT and entry.HugePage)) return null;
        writable = writable and entry.Writable;
        user_accessible = user_accessible and entry.UserAccessible;
        executable = executable and !entry.NoExecute;
        if (shift == indices.PT_SHIFT or entry.HugePage) {
            const page_size = @as(u64, 1) << shift;
            const encoded_address = entry.getPhysicalAddress();
            if (shift != indices.PT_SHIFT and (encoded_address & (page_size - 1) & ~sizes.PAGE_SIZE) != 0) return null;
            const physical_base = encoded_address & ~(page_size - 1);
            const limit = state.getPolicy().PhysicalLimit;
            if (physical_base >= limit or page_size > limit - physical_base) return null;
            return .{
                .Entry = entry,
                .PhysicalAddress = physical_base + (virtual_address & (page_size - 1)),
                .PageSize = page_size,
                .Writable = writable,
                .UserAccessible = user_accessible,
                .Executable = executable,
            };
        }
        physical_address = entry.getPhysicalAddress();
    }
    return null;
}

pub fn walkToEntry(pml4_physical: u64, virtual_address: u64) ?*const Entry {
    const resolved = lookup(pml4_physical, virtual_address) orelse return null;
    if (resolved.PageSize != sizes.PAGE_SIZE) return null;
    return resolved.Entry;
}

pub fn walkToOwnedEntry(pml4_physical: u64, virtual_address: u64) ?*Entry {
    if (!isCanonical(virtual_address) or !isValidTable(pml4_physical)) return null;
    var physical_address = pml4_physical;
    var visited: [sizes.PAGE_TABLE_LEVELS]u64 = undefined;
    const shifts = [_]u6{ indices.PML4_SHIFT, indices.PDPT_SHIFT, indices.PD_SHIFT };
    for (shifts, 0..) |shift, level| {
        for (visited[0..level]) |ancestor| {
            if (physical_address == ancestor) return null;
        }
        visited[level] = physical_address;
        const table = getTableFromPhysical(physical_address);
        const entry = &table.Entries[@intCast((virtual_address >> shift) & indices.INDEX_MASK)];
        if (!entry.Present or entry.HugePage or !entry.isOwnedTable()) return null;
        physical_address = entry.getPhysicalAddress();
        if (!isValidTable(physical_address)) return null;
    }
    for (visited[0..shifts.len]) |ancestor| {
        if (physical_address == ancestor) return null;
    }
    const table = getTableFromPhysical(physical_address);
    return &table.Entries[@intCast((virtual_address >> indices.PT_SHIFT) & indices.INDEX_MASK)];
}
