//! Transactional Owned Page Table Allocation

const common = @import("common");
const constants = @import("mirai").kagami.constants;
const guard = @import("asm").interrupts.guard;
const pmm = @import("mirai").pmm;
const policy = @import("mirai").kagami.policy;
const types = @import("mirai").kagami.types;
const walk = @import("mirai").kagami.tables.walk;

const indices = common.constants.paging.indices;
const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.allocation.AllocationError;
const MappingError = common.errors.memory.mapping.MappingError;
const Entry = types.entry.Entry;
const Kagami = types.kagami.Kagami;

pub fn allocateTable() AllocationError!u64 {
    const physical_address = try pmm.allocate.single.allocatePage();
    if (!walk.isValidTable(physical_address)) {
        pmm.free.single.freePage(physical_address);
        return AllocationError.OutOfMemory;
    }
    walk.getTableFromPhysical(physical_address).clearAll();
    return physical_address;
}

pub fn freeTable(physical_address: u64) void {
    pmm.free.single.freePage(physical_address);
}

pub fn ensureTables(kagami: *Kagami, virtual_address: u64) (AllocationError || MappingError)!*Entry {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try policy.canMutate(kagami, virtual_address);
    const user_half = virtual_address <= common.constants.memory.layout.USER_SPACE_END;
    var current_physical = kagami.PML4Physical;
    var pending_frames: [constants.bootstrap.MAX_INTERMEDIATE_TABLES]u64 = undefined;
    var pending_count: usize = 0;
    var first_parent: ?*Entry = null;
    var first_physical: u64 = 0;
    var visited: [constants.bootstrap.MAX_INTERMEDIATE_TABLES]u64 = undefined;
    errdefer {
        for (pending_frames[0..pending_count]) |physical_address| freeTable(physical_address);
    }
    const shifts = [_]u6{ indices.PML4_SHIFT, indices.PDPT_SHIFT, indices.PD_SHIFT };
    for (shifts, 0..) |shift, level| {
        for (visited[0..level]) |ancestor| {
            if (current_physical == ancestor) return MappingError.InvalidAddress;
        }
        visited[level] = current_physical;
        if (!walk.isValidTable(current_physical)) return MappingError.InvalidAddress;
        const current = walk.getTableFromPhysical(current_physical);
        const entry = &current.Entries[@intCast((virtual_address >> shift) & indices.INDEX_MASK)];
        if (entry.Present) {
            if (entry.HugePage) return AllocationError.HugeMappingConflict;
            if (!entry.isOwnedTable() or !entry.Writable or entry.NoExecute or entry.UserAccessible != user_half) return MappingError.PermissionDenied;
            current_physical = entry.getPhysicalAddress();
            continue;
        }
        if (kagami.TablePages + pending_count >= constants.bootstrap.MAX_TABLE_FRAMES) return AllocationError.RegionExhausted;
        const new_physical = try allocateTable();
        pending_frames[pending_count] = new_physical;
        pending_count += 1;
        if (first_parent == null) {
            first_parent = entry;
            first_physical = new_physical;
        } else {
            entry.* = tableEntry(new_physical, user_half);
        }
        current_physical = new_physical;
    }
    for (visited) |ancestor| {
        if (current_physical == ancestor) return MappingError.InvalidAddress;
    }
    if (!walk.isValidTable(current_physical)) return MappingError.InvalidAddress;
    const leaf = walk.getTableFromPhysical(current_physical);
    if (first_parent) |parent| {
        parent.* = tableEntry(first_physical, user_half);
        kagami.TablePages += pending_count;
    }
    return &leaf.Entries[@intCast((virtual_address >> indices.PT_SHIFT) & indices.INDEX_MASK)];
}

fn tableEntry(physical_address: u64, user_accessible: bool) Entry {
    var entry = Entry{
        .Present = true,
        .Writable = true,
        .UserAccessible = user_accessible,
        .AvailableLow = constants.ownership.OWNED_TABLE,
    };
    entry.setPhysicalAddress(physical_address);
    return entry;
}
