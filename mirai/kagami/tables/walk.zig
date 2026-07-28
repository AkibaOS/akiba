//! Page Table Walking

const types = @import("mirai").kagami.types;

const address = @import("utils").address;

const Entry = types.entry.Entry;
const Table = types.table.Table;

pub fn getTableFromPhysical(physical_address: u64) *Table {
    const virtual_address = address.translate.physToVirt(physical_address);
    return @ptrFromInt(virtual_address);
}

pub fn getPML4(pml4_physical: u64) *Table {
    return getTableFromPhysical(pml4_physical);
}

pub fn getPDPT(pml4: *Table, virtual_address: u64) ?*Table {
    const pml4_index = address.decompose.extractPML4Index(virtual_address);
    const entry = pml4.getEntry(pml4_index);

    if (!entry.isPresent()) {
        return null;
    }

    return getTableFromPhysical(entry.getPhysicalAddress());
}

pub fn getPD(pdpt: *Table, virtual_address: u64) ?*Table {
    const pdpt_index = address.decompose.extractPDPTIndex(virtual_address);
    const entry = pdpt.getEntry(pdpt_index);

    if (!entry.isPresent()) {
        return null;
    }

    if (entry.isHuge()) {
        return null;
    }

    return getTableFromPhysical(entry.getPhysicalAddress());
}

pub fn getPT(pd: *Table, virtual_address: u64) ?*Table {
    const pd_index = address.decompose.extractPDIndex(virtual_address);
    const entry = pd.getEntry(pd_index);

    if (!entry.isPresent()) {
        return null;
    }

    if (entry.isHuge()) {
        return null;
    }

    return getTableFromPhysical(entry.getPhysicalAddress());
}

pub fn getPageEntry(pt: *Table, virtual_address: u64) *Entry {
    const pt_index = address.decompose.extractPTIndex(virtual_address);
    return pt.getEntry(pt_index);
}

pub fn walkToEntry(pml4_physical: u64, virtual_address: u64) ?*Entry {
    const pml4 = getPML4(pml4_physical);

    const pdpt = getPDPT(pml4, virtual_address) orelse return null;
    const pd = getPD(pdpt, virtual_address) orelse return null;
    const pt = getPT(pd, virtual_address) orelse return null;

    return getPageEntry(pt, virtual_address);
}
