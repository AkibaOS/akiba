//! Page Table Allocation

const common = @import("root").common;
const pmm = @import("../../pmm/pmm.zig");
const types = @import("../types/types.zig");
const walk = @import("walk.zig");

const paging = common.constants.paging;
const memory = common.constants.memory;
const AllocationError = common.errors.memory.AllocationError;

const Entry = types.Entry;
const Table = types.Table;
const Kagami = types.Kagami;

pub fn allocate_table() AllocationError!u64 {
    const physical_address = try pmm.allocate_page_zeroed();
    return physical_address;
}

pub fn free_table(physical_address: u64) void {
    pmm.free_page(physical_address);
}

pub fn ensure_pdpt(kagami: *Kagami, virtual_address: u64) AllocationError!*Table {
    const pml4 = walk.get_pml4(kagami.pml4_physical);
    const pml4_index = paging.indices.extract_pml4_index(virtual_address);
    const entry = pml4.get_entry(pml4_index);

    if (entry.is_present()) {
        return walk.get_table_from_physical(entry.get_physical_address());
    }

    const new_table_physical = try allocate_table();
    kagami.add_table();

    entry.* = Entry{
        .present = true,
        .writable = true,
        .user_accessible = (pml4_index < 256),
    };
    entry.set_physical_address(new_table_physical);

    return walk.get_table_from_physical(new_table_physical);
}

pub fn ensure_pd(kagami: *Kagami, pdpt: *Table, virtual_address: u64) AllocationError!*Table {
    const pdpt_index = paging.indices.extract_pdpt_index(virtual_address);
    const entry = pdpt.get_entry(pdpt_index);

    if (entry.is_present()) {
        return walk.get_table_from_physical(entry.get_physical_address());
    }

    const new_table_physical = try allocate_table();
    kagami.add_table();

    const pml4_index = paging.indices.extract_pml4_index(virtual_address);

    entry.* = Entry{
        .present = true,
        .writable = true,
        .user_accessible = (pml4_index < 256),
    };
    entry.set_physical_address(new_table_physical);

    return walk.get_table_from_physical(new_table_physical);
}

pub fn ensure_pt(kagami: *Kagami, pd: *Table, virtual_address: u64) AllocationError!*Table {
    const pd_index = paging.indices.extract_pd_index(virtual_address);
    const entry = pd.get_entry(pd_index);

    if (entry.is_present()) {
        return walk.get_table_from_physical(entry.get_physical_address());
    }

    const new_table_physical = try allocate_table();
    kagami.add_table();

    const pml4_index = paging.indices.extract_pml4_index(virtual_address);

    entry.* = Entry{
        .present = true,
        .writable = true,
        .user_accessible = (pml4_index < 256),
    };
    entry.set_physical_address(new_table_physical);

    return walk.get_table_from_physical(new_table_physical);
}

pub fn ensure_tables(kagami: *Kagami, virtual_address: u64) AllocationError!*Entry {
    const pdpt = try ensure_pdpt(kagami, virtual_address);
    const pd = try ensure_pd(kagami, pdpt, virtual_address);
    const pt = try ensure_pt(kagami, pd, virtual_address);

    const pt_index = paging.indices.extract_pt_index(virtual_address);
    return pt.get_entry(pt_index);
}
