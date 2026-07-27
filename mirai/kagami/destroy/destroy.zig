//! Destroy Kagami

const constants = @import("../constants/constants.zig");
const create = @import("../create/create.zig");
const pmm = @import("../../pmm/pmm.zig");
const tables = @import("../tables/tables.zig");
const types = @import("../types/types.zig");

const Kagami = types.kagami.Kagami;
const Table = types.table.Table;

pub fn destroy(kagami: *Kagami) void {
    if (kagami.isKernel()) {
        return;
    }

    const remaining = kagami.decrementReference();
    if (remaining > 0) {
        return;
    }

    freeUserTables(kagami);

    pmm.free.single.freePage(kagami.PML4Physical);

    create.freeKagamiStruct(kagami);
}

fn freeUserTables(kagami: *Kagami) void {
    const pml4 = tables.walk.getPML4(kagami.PML4Physical);

    var pml4_index: u9 = 0;
    while (pml4_index < constants.tables.KERNEL_PML4_START) : (pml4_index += 1) {
        const pml4_entry = pml4.getEntry(pml4_index);
        if (!pml4_entry.isPresent()) continue;

        const pdpt = tables.walk.getTableFromPhysical(pml4_entry.getPhysicalAddress());
        freePDPT(pdpt);

        pmm.free.single.freePage(pml4_entry.getPhysicalAddress());
        pml4_entry.clear();
    }
}

fn freePDPT(pdpt: *Table) void {
    var pdpt_index: u32 = 0;
    while (pdpt_index < constants.tables.PDPT_ENTRIES) : (pdpt_index += 1) {
        const pdpt_entry = pdpt.getEntry(@truncate(pdpt_index));
        if (!pdpt_entry.isPresent()) continue;
        if (pdpt_entry.isHuge()) continue;

        const pd = tables.walk.getTableFromPhysical(pdpt_entry.getPhysicalAddress());
        freePD(pd);

        pmm.free.single.freePage(pdpt_entry.getPhysicalAddress());
        pdpt_entry.clear();
    }
}

fn freePD(pd: *Table) void {
    var pd_index: u32 = 0;
    while (pd_index < constants.tables.PD_ENTRIES) : (pd_index += 1) {
        const pd_entry = pd.getEntry(@truncate(pd_index));
        if (!pd_entry.isPresent()) continue;
        if (pd_entry.isHuge()) continue;

        pmm.free.single.freePage(pd_entry.getPhysicalAddress());
        pd_entry.clear();
    }
}

pub fn reference(kagami: *Kagami) void {
    kagami.incrementReference();
}

pub fn release(kagami: *Kagami) void {
    destroy(kagami);
}
