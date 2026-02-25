//! Destroy Kagami

const pmm = @import("../../pmm/pmm.zig");
const types = @import("../types/types.zig");
const state = @import("../state.zig");
const tables = @import("../tables/tables.zig");
const create_module = @import("../create/create.zig");

const Kagami = types.Kagami;
const Table = types.Table;

pub fn destroy(kagami: *Kagami) void {
    if (kagami.is_kernel()) {
        return;
    }

    const remaining = kagami.decrement_reference();
    if (remaining > 0) {
        return;
    }

    free_user_tables(kagami);

    pmm.free_page(kagami.pml4_physical);

    create_module.free_kagami_struct(kagami);
}

fn free_user_tables(kagami: *Kagami) void {
    const pml4 = tables.get_pml4(kagami.pml4_physical);

    var pml4_index: u9 = 0;
    while (pml4_index < 256) : (pml4_index += 1) {
        const pml4_entry = pml4.get_entry(pml4_index);
        if (!pml4_entry.is_present()) continue;

        const pdpt = tables.get_table_from_physical(pml4_entry.get_physical_address());
        free_pdpt(pdpt);

        pmm.free_page(pml4_entry.get_physical_address());
        pml4_entry.clear();
    }
}

fn free_pdpt(pdpt: *Table) void {
    var pdpt_index: u9 = 0;
    while (pdpt_index < 512) : (pdpt_index += 1) {
        const pdpt_entry = pdpt.get_entry(pdpt_index);
        if (!pdpt_entry.is_present()) continue;
        if (pdpt_entry.is_huge()) continue;

        const pd = tables.get_table_from_physical(pdpt_entry.get_physical_address());
        free_pd(pd);

        pmm.free_page(pdpt_entry.get_physical_address());
        pdpt_entry.clear();
    }
}

fn free_pd(pd: *Table) void {
    var pd_index: u9 = 0;
    while (pd_index < 512) : (pd_index += 1) {
        const pd_entry = pd.get_entry(pd_index);
        if (!pd_entry.is_present()) continue;
        if (pd_entry.is_huge()) continue;

        pmm.free_page(pd_entry.get_physical_address());
        pd_entry.clear();
    }
}

pub fn reference(kagami: *Kagami) void {
    kagami.increment_reference();
}

pub fn release(kagami: *Kagami) void {
    destroy(kagami);
}
