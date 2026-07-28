//! Remove Mapping

const common = @import("common");

const cpu = @import("asm").cpu;

const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const sizes = common.constants.memory.sizes;

const Kagami = types.kagami.Kagami;

pub fn remove(kagami: *Kagami, virtual_address: u64) ?u64 {
    const entry = tables.walk.walkToEntry(kagami.PML4Physical, virtual_address) orelse return null;

    if (!entry.isPresent()) {
        return null;
    }

    const physical_address = entry.getPhysicalAddress();

    entry.clear();

    kagami.removeResident();

    cpu.control.invalidatePage(virtual_address);

    return physical_address;
}

pub fn removeRange(kagami: *Kagami, start_address: u64, page_count: u64) u64 {
    var removed_count: u64 = 0;
    var offset: u64 = 0;

    while (offset < page_count) : (offset += 1) {
        const virtual_address = start_address + (offset * sizes.PAGE_SIZE);
        if (remove(kagami, virtual_address) != null) {
            removed_count += 1;
        }
    }

    return removed_count;
}
