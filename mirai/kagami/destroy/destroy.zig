//! Validated Inactive User Root Destruction

const std = @import("std");

const common = @import("common");
const constants = @import("mirai").kagami.constants;
const cpu = @import("asm").cpu;
const create = @import("mirai").kagami.create;
const state = @import("mirai").kagami.state;
const synchronize = @import("mirai").kagami.synchronize;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const indices = common.constants.paging.indices;
const sizes = common.constants.memory.sizes;
const Kagami = types.kagami.Kagami;

pub fn destroy(kagami: *Kagami) void {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    if (!create.owns(kagami) or kagami.Ownership != .User or !kagami.SharesKernel or
        kagami == state.getCurrentKagami() or kagami == state.getKernelKagami() or
        (cpu.control.readCR3() & indices.ADDRESS_MASK) == kagami.PML4Physical) return;
    if (kagami.ReferenceCount > 1) {
        kagami.ReferenceCount -= 1;
        return;
    }
    if (kagami.TablePages == 0 or kagami.TablePages > constants.bootstrap.MAX_TABLE_FRAMES) return;
    const root = tables.walk.getPML4(kagami.PML4Physical);
    const kernel = tables.walk.getPML4(state.getKernelKagami().PML4Physical);
    var upper: usize = constants.tables.KERNEL_PML4_START;
    while (upper < sizes.ENTRIES_PER_PAGE_TABLE) : (upper += 1) {
        const shared = root.Entries[upper];
        if (!shared.Present or shared.HugePage or shared.isOwnedTable() or shared.UserAccessible or
            (shared.AvailableLow & constants.ownership.SHARED_TABLE) == 0 or
            shared.getPhysicalAddress() != kernel.Entries[upper].getPhysicalAddress()) return;
    }
    var owned_frames: [constants.bootstrap.MAX_TABLE_FRAMES]u64 = undefined;
    var owned_count: usize = 0;
    if (!collectOwned(kagami.PML4Physical, sizes.PAGE_TABLE_LEVELS, &owned_frames, &owned_count) or
        owned_count != kagami.TablePages) return;
    root.clearAll();
    cpu.control.flushAllTLB();
    while (owned_count != 0) {
        owned_count -= 1;
        tables.allocate.freeTable(owned_frames[owned_count]);
    }
    kagami.PML4Physical = 0;
    kagami.ReferenceCount = 0;
    kagami.ResidentPages = 0;
    kagami.WiredPages = 0;
    kagami.TablePages = 0;
    create.freeKagamiStruct(kagami);
}

fn collectOwned(physical_address: u64, level: u8, owned_frames: *[constants.bootstrap.MAX_TABLE_FRAMES]u64, owned_count: *usize) bool {
    if (!tables.walk.isValidTable(physical_address) or owned_count.* == owned_frames.len) return false;
    for (owned_frames[0..owned_count.*]) |existing| {
        if (existing == physical_address) return false;
    }
    owned_frames[owned_count.*] = physical_address;
    owned_count.* += 1;
    if (level == 1) return true;
    const table = tables.walk.getTableFromPhysical(physical_address);
    const entry_limit = if (level == sizes.PAGE_TABLE_LEVELS) constants.tables.USER_PML4_END else sizes.ENTRIES_PER_PAGE_TABLE;
    for (table.Entries[0..entry_limit]) |entry| {
        if (!entry.Present) continue;
        if (entry.HugePage) {
            if (level == sizes.PAGE_TABLE_LEVELS) return false;
            continue;
        }
        if (!entry.isOwnedTable() or !collectOwned(entry.getPhysicalAddress(), level - 1, owned_frames, owned_count)) return false;
    }
    return true;
}

pub fn reference(kagami: *Kagami) void {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    if (create.owns(kagami) and kagami.ReferenceCount != std.math.maxInt(u32)) kagami.ReferenceCount += 1;
}

pub fn release(kagami: *Kagami) void {
    destroy(kagami);
}
