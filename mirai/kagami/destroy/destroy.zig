//! Validated Inactive User Root Destruction

const std = @import("std");

const common = @import("common");
const constants = @import("mirai").kagami.constants;
const cpu = @import("asm").cpu;
const create = @import("mirai").kagami.create;
const guard = @import("asm").interrupts.guard;
const state = @import("mirai").kagami.state;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const indices = common.constants.paging.indices;
const sizes = common.constants.memory.sizes;
const DestroyResult = types.destruction.DestroyResult;
const Kagami = types.kagami.Kagami;

pub fn destroy(kagami: *Kagami) DestroyResult {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!create.owns(kagami)) return .Refused;
    if (kagami.ExecutionOwners != 0 or kagami.Ownership != .User or !kagami.SharesKernel or
        kagami == state.getCurrentKagami() or kagami == state.getKernelKagami() or
        (cpu.control.readCR3() & indices.ADDRESS_MASK) == kagami.PML4Physical) return .Refused;
    if (kagami.ReferenceCount > 1) {
        kagami.ReferenceCount -= 1;
        return .Retained;
    }
    if (!validate(kagami)) return .Refused;
    const root = tables.walk.getPML4(kagami.PML4Physical);
    root.clearAll();
    cpu.control.flushAllTLB();
    while (kagami.Frames) |frame| tables.allocate.freeTable(kagami, frame.PA);
    kagami.PML4Physical = 0;
    kagami.ReferenceCount = 0;
    kagami.ResidentPages = 0;
    kagami.WiredPages = 0;
    if (!create.freeKagamiStruct(kagami)) unreachable;
    return .Destroyed;
}

pub fn validate(kagami: *Kagami) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!create.owns(kagami) or !kagami.SharesKernel or kagami.TablePages == 0 or
        !tables.ownership.reset(kagami)) return false;
    defer _ = tables.ownership.reset(kagami);
    const root = tables.walk.getPML4(kagami.PML4Physical);
    const kernel = tables.walk.getPML4(state.getKernelKagami().PML4Physical);
    var upper: usize = constants.tables.geometry.KERNEL_PML4_START;
    while (upper < sizes.ENTRIES_PER_PAGE_TABLE) : (upper += 1) {
        const shared = root.Entries[upper];
        if (!shared.Present or shared.HugePage or shared.isOwnedTable() or shared.UserAccessible or
            (shared.AvailableLow & constants.ownership.SHARED_TABLE) == 0 or
            shared.getPhysicalAddress() != kernel.Entries[upper].getPhysicalAddress()) return false;
    }
    var owned_count: u64 = 0;
    return validateOwned(kagami, kagami.PML4Physical, sizes.PAGE_TABLE_LEVELS, &owned_count) and
        owned_count == kagami.TablePages;
}

fn validateOwned(owner: *const Kagami, physical_address: u64, level: u8, count: *u64) bool {
    if (!tables.walk.isValidTable(physical_address) or !tables.ownership.visit(owner, physical_address) or
        count.* == owner.TablePages) return false;
    count.* += 1;
    if (level == 1) return true;
    const table = tables.walk.getTableFromPhysical(physical_address);
    const entry_limit = if (level == sizes.PAGE_TABLE_LEVELS) constants.tables.geometry.USER_PML4_END else sizes.ENTRIES_PER_PAGE_TABLE;
    for (table.Entries[0..entry_limit]) |entry| {
        if (!entry.Present) continue;
        if (entry.HugePage) {
            if (level == sizes.PAGE_TABLE_LEVELS) return false;
            continue;
        }
        if (!entry.isOwnedTable() or !validateOwned(owner, entry.getPhysicalAddress(), level - 1, count)) return false;
    }
    return true;
}

pub fn reference(kagami: *Kagami) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (create.owns(kagami) and kagami.ReferenceCount != std.math.maxInt(u32)) kagami.ReferenceCount += 1;
}

pub fn release(kagami: *Kagami) void {
    _ = destroy(kagami);
}
