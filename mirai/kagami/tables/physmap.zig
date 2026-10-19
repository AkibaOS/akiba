//! Transactional Owned User Physmap Splitting

const checks = @import("mirai").user.state.checks;
const common = @import("common");
const constants = @import("mirai").kagami.constants;
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const ledger = @import("mirai").user.state.ledger;
const pmm = @import("mirai").pmm;
const state = @import("mirai").kagami.state;
const types = @import("mirai").kagami.types;
const usererrors = @import("mirai").user.errors.memory;
const walk = @import("mirai").kagami.tables.walk;

const indices = common.constants.paging.indices;
const layout = common.constants.memory.layout;
const limits = constants.physmap;
const sizes = common.constants.memory.sizes;
const Entry = types.entry.Entry;
const Kata = kata.types.kata.Kata;
const Lookup = types.lookup.Lookup;
const Table = types.table.Table;
const UserError = usererrors.UserError;

pub fn prepare(owner: *const Kata, virtual_address: u64) UserError!*Entry {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!checks.isValidOwner(owner)) return UserError.InvalidOwner;
    const record = ledger.find(owner, virtual_address) orelse return UserError.NotOwned;
    if (record.Stage != .Loading) return UserError.SealedPage;
    const resolved = checks.lookupAlias(record) orelse return UserError.InvalidPhysmap;
    if (!resolved.Writable) return UserError.InvalidPhysmap;
    try validatePath(layout.PHYSMAP_BASE + record.PA, resolved.Entry);
    if (resolved.PageSize == sizes.PAGE_SIZE) return @constCast(resolved.Entry);
    if (resolved.PageSize != sizes.LARGE_PAGE_SIZE and resolved.PageSize != sizes.HUGE_PAGE_SIZE) return UserError.InvalidPhysmap;
    return split(record.PA, resolved);
}

fn validatePath(virtual_address: u64, leaf: *const Entry) UserError!void {
    var current_physical = state.getKernelKagami().PML4Physical;
    var visited: [limits.PARENT_SHIFTS.len]u64 = undefined;
    for (limits.PARENT_SHIFTS, 0..) |shift, level| {
        if (!walk.isValidTable(current_physical) or containsTable(visited[0..level], current_physical)) return UserError.InvalidPhysmap;
        visited[level] = current_physical;
        const table = walk.getTableFromPhysical(current_physical);
        const entry = &table.Entries[@intCast((virtual_address >> shift) & indices.INDEX_MASK)];
        if (entry == leaf) return;
        if (!entry.Present or entry.HugePage or !entry.isOwnedTable() or entry.UserAccessible or
            !entry.Writable or entry.NoExecute or entry.WriteThrough or entry.CacheDisabled) return UserError.InvalidPhysmap;
        current_physical = entry.getPhysicalAddress();
    }
    if (!walk.isValidTable(current_physical) or containsTable(&visited, current_physical)) return UserError.InvalidPhysmap;
    const table = walk.getTableFromPhysical(current_physical);
    if (&table.Entries[@intCast((virtual_address >> indices.PT_SHIFT) & indices.INDEX_MASK)] != leaf) return UserError.InvalidPhysmap;
}

fn containsTable(visited: []const u64, physical_address: u64) bool {
    for (visited) |ancestor| {
        if (ancestor == physical_address) return true;
    }
    return false;
}

fn split(physical_address: u64, resolved: Lookup) UserError!*Entry {
    const kernel = state.getKernelKagami();
    const required: usize = if (resolved.PageSize == sizes.HUGE_PAGE_SIZE) 2 else 1;
    if (kernel.TablePages > constants.bootstrap.MAX_TABLE_FRAMES or
        required > constants.bootstrap.MAX_TABLE_FRAMES - kernel.TablePages) return UserError.RegionExhausted;
    const previous_search = pmm.state.getState().SearchStart;
    var frames: [limits.MAX_SPLIT_TABLES]u64 = undefined;
    var count: usize = 0;
    errdefer {
        for (frames[0..count]) |frame| pmm.free.single.freePage(frame);
        pmm.state.getState().SearchStart = previous_search;
    }
    while (count < required) : (count += 1) frames[count] = try allocateTable();
    const original = resolved.Entry.*;
    const pt = walk.getTableFromPhysical(frames[required - 1]);
    populate(pt, original, physical_address & ~sizes.LARGE_PAGE_MASK, sizes.PAGE_SIZE);
    if (required == 2) {
        const pd = walk.getTableFromPhysical(frames[0]);
        populate(pd, original, physical_address & ~sizes.HUGE_PAGE_MASK, sizes.LARGE_PAGE_SIZE);
        pd.Entries[@intCast((physical_address >> indices.PD_SHIFT) & indices.INDEX_MASK)] = tableEntry(frames[1]);
    }
    const parent: *Entry = @constCast(resolved.Entry);
    parent.* = tableEntry(frames[0]);
    kernel.TablePages += required;
    cpu.control.flushAllTLB();
    return &pt.Entries[@intCast((physical_address >> indices.PT_SHIFT) & indices.INDEX_MASK)];
}

fn allocateTable() UserError!u64 {
    const physical_address = try pmm.allocate.single.allocatePage();
    errdefer pmm.free.single.freePage(physical_address);
    if (!walk.isValidTable(physical_address) or !checks.isPayloadPhysical(physical_address) or
        ledger.ownsPhysical(physical_address)) return UserError.InvalidPhysmap;
    const resolved = walk.lookup(state.getKernelKagami().PML4Physical, layout.PHYSMAP_BASE + physical_address) orelse return UserError.InvalidPhysmap;
    if (resolved.PhysicalAddress != physical_address or !resolved.Writable or resolved.UserAccessible or
        resolved.Executable or !resolved.Entry.NoExecute or resolved.Entry.WriteThrough or resolved.Entry.CacheDisabled) return UserError.InvalidPhysmap;
    const pat = if (resolved.PageSize == sizes.PAGE_SIZE) resolved.Entry.HugePage else (resolved.Entry.getPhysicalAddress() & limits.BIG_PAT) != 0;
    if (pat) return UserError.InvalidPhysmap;
    walk.getTableFromPhysical(physical_address).clearAll();
    return physical_address;
}

fn populate(table: *Table, source: Entry, physical_base: u64, page_size: u64) void {
    const pat = (source.getPhysicalAddress() & limits.BIG_PAT) != 0;
    for (&table.Entries, 0..) |*entry, index| {
        entry.* = source;
        const physical_address = physical_base + index * page_size;
        const encoded_pat = if (page_size != sizes.PAGE_SIZE and pat) limits.BIG_PAT else 0;
        entry.setPhysicalAddress(physical_address | encoded_pat);
        entry.HugePage = if (page_size == sizes.PAGE_SIZE) pat else true;
    }
}

fn tableEntry(physical_address: u64) Entry {
    var entry = Entry{
        .Present = true,
        .Writable = true,
        .AvailableLow = constants.ownership.OWNED_TABLE,
    };
    entry.setPhysicalAddress(physical_address);
    return entry;
}
