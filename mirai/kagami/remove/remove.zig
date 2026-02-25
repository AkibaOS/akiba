//! Remove Mapping

const types = @import("../types/types.zig");
const tables = @import("../tables/tables.zig");
const asm_cpu = @import("../../asm/cpu/cpu.zig");

const Entry = types.Entry;
const Kagami = types.Kagami;

pub fn remove(kagami: *Kagami, virtual_address: u64) ?u64 {
    const entry = tables.walk_to_entry(kagami.pml4_physical, virtual_address) orelse return null;

    if (!entry.is_present()) {
        return null;
    }

    const physical_address = entry.get_physical_address();

    entry.clear();

    kagami.remove_resident();

    asm_cpu.invalidate_page(virtual_address);

    return physical_address;
}

pub fn remove_range(kagami: *Kagami, start_address: u64, page_count: u64) u64 {
    var removed_count: u64 = 0;
    var offset: u64 = 0;

    while (offset < page_count) : (offset += 1) {
        const virtual_address = start_address + (offset * 4096);
        if (remove(kagami, virtual_address) != null) {
            removed_count += 1;
        }
    }

    return removed_count;
}
