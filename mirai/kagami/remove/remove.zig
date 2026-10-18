//! Owned Four Kilobyte Mapping Removal

const common = @import("common");
const cpu = @import("asm").cpu;
const policy = @import("mirai").kagami.policy;
const synchronize = @import("mirai").kagami.synchronize;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const sizes = common.constants.memory.sizes;
const Kagami = types.kagami.Kagami;

pub fn remove(kagami: *Kagami, virtual_address: u64) ?u64 {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    policy.canMutate(kagami, virtual_address) catch return null;
    const entry = tables.walk.walkToOwnedEntry(kagami.PML4Physical, virtual_address) orelse return null;
    if (!entry.Present) return null;
    const physical_address = entry.getPhysicalAddress();
    const was_wired = entry.isWired();
    entry.clear();
    kagami.removeResident();
    if (was_wired) kagami.removeWired();
    cpu.control.invalidatePage(virtual_address);
    tables.prune.prune(kagami, virtual_address);
    return physical_address;
}

pub fn removeRange(kagami: *Kagami, start_address: u64, page_count: u64) u64 {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    var removed_count: u64 = 0;
    var offset: u64 = 0;
    var virtual_address = start_address;
    while (offset < page_count) : (offset += 1) {
        if (remove(kagami, virtual_address) != null) removed_count += 1;
        const next = @addWithOverflow(virtual_address, sizes.PAGE_SIZE);
        if (next[1] != 0) break;
        virtual_address = next[0];
    }
    return removed_count;
}
