//! Page Table Walking

const common = @import("../../../common/common.zig");
const types = @import("../types/types.zig");

const paging = common.constants.paging;
const memory = common.constants.memory;

const Entry = types.Entry;
const Table = types.Table;

pub fn get_table_from_physical(physical_address: u64) *Table {
    const virtual_address = physical_address + memory.layout.physmap_base;
    return @ptrFromInt(virtual_address);
}

pub fn get_pml4(pml4_physical: u64) *Table {
    return get_table_from_physical(pml4_physical);
}

pub fn get_pdpt(pml4: *Table, virtual_address: u64) ?*Table {
    const pml4_index = paging.indices.extract_pml4_index(virtual_address);
    const entry = pml4.get_entry(pml4_index);

    if (!entry.is_present()) {
        return null;
    }

    return get_table_from_physical(entry.get_physical_address());
}

pub fn get_pd(pdpt: *Table, virtual_address: u64) ?*Table {
    const pdpt_index = paging.indices.extract_pdpt_index(virtual_address);
    const entry = pdpt.get_entry(pdpt_index);

    if (!entry.is_present()) {
        return null;
    }

    if (entry.is_huge()) {
        return null;
    }

    return get_table_from_physical(entry.get_physical_address());
}

pub fn get_pt(pd: *Table, virtual_address: u64) ?*Table {
    const pd_index = paging.indices.extract_pd_index(virtual_address);
    const entry = pd.get_entry(pd_index);

    if (!entry.is_present()) {
        return null;
    }

    if (entry.is_huge()) {
        return null;
    }

    return get_table_from_physical(entry.get_physical_address());
}

pub fn get_page_entry(pt: *Table, virtual_address: u64) *Entry {
    const pt_index = paging.indices.extract_pt_index(virtual_address);
    return pt.get_entry(pt_index);
}

pub fn walk_to_entry(pml4_physical: u64, virtual_address: u64) ?*Entry {
    const pml4 = get_pml4(pml4_physical);

    const pdpt = get_pdpt(pml4, virtual_address) orelse return null;
    const pd = get_pd(pdpt, virtual_address) orelse return null;
    const pt = get_pt(pd, virtual_address) orelse return null;

    return get_page_entry(pt, virtual_address);
}
