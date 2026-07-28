//! Page Table Allocation

const common = @import("common");

const constants = @import("mirai").kagami.constants;

const pmm = @import("mirai").pmm;
const types = @import("mirai").kagami.types;
const walk = @import("mirai").kagami.tables.walk;

const address = @import("utils").address;

const AllocationError = common.errors.memory.allocation.AllocationError;

const Entry = types.entry.Entry;
const Kagami = types.kagami.Kagami;
const Table = types.table.Table;

pub fn allocateTable() AllocationError!u64 {
    const physical_address = try pmm.allocate.single.allocatePageZeroed();
    return physical_address;
}

pub fn freeTable(physical_address: u64) void {
    pmm.free.single.freePage(physical_address);
}

pub fn ensurePDPT(kagami: *Kagami, virtual_address: u64) AllocationError!*Table {
    const pml4 = walk.getPML4(kagami.PML4Physical);
    const pml4_index = address.decompose.extractPML4Index(virtual_address);
    const entry = pml4.getEntry(pml4_index);

    if (entry.isPresent()) {
        return walk.getTableFromPhysical(entry.getPhysicalAddress());
    }

    const new_table_physical = try allocateTable();
    kagami.addTable();

    entry.* = Entry{
        .Present = true,
        .Writable = true,
        .UserAccessible = (pml4_index < constants.tables.KERNEL_PML4_START),
    };
    entry.setPhysicalAddress(new_table_physical);

    return walk.getTableFromPhysical(new_table_physical);
}

pub fn ensurePD(kagami: *Kagami, pdpt: *Table, virtual_address: u64) AllocationError!*Table {
    const pdpt_index = address.decompose.extractPDPTIndex(virtual_address);
    const entry = pdpt.getEntry(pdpt_index);

    if (entry.isPresent()) {
        return walk.getTableFromPhysical(entry.getPhysicalAddress());
    }

    const new_table_physical = try allocateTable();
    kagami.addTable();

    const pml4_index = address.decompose.extractPML4Index(virtual_address);

    entry.* = Entry{
        .Present = true,
        .Writable = true,
        .UserAccessible = (pml4_index < constants.tables.KERNEL_PML4_START),
    };
    entry.setPhysicalAddress(new_table_physical);

    return walk.getTableFromPhysical(new_table_physical);
}

pub fn ensurePT(kagami: *Kagami, pd: *Table, virtual_address: u64) AllocationError!*Table {
    const pd_index = address.decompose.extractPDIndex(virtual_address);
    const entry = pd.getEntry(pd_index);

    if (entry.isPresent()) {
        return walk.getTableFromPhysical(entry.getPhysicalAddress());
    }

    const new_table_physical = try allocateTable();
    kagami.addTable();

    const pml4_index = address.decompose.extractPML4Index(virtual_address);

    entry.* = Entry{
        .Present = true,
        .Writable = true,
        .UserAccessible = (pml4_index < constants.tables.KERNEL_PML4_START),
    };
    entry.setPhysicalAddress(new_table_physical);

    return walk.getTableFromPhysical(new_table_physical);
}

pub fn ensureTables(kagami: *Kagami, virtual_address: u64) AllocationError!*Entry {
    const pdpt = try ensurePDPT(kagami, virtual_address);
    const pd = try ensurePD(kagami, pdpt, virtual_address);
    const pt = try ensurePT(kagami, pd, virtual_address);

    const pt_index = address.decompose.extractPTIndex(virtual_address);
    return pt.getEntry(pt_index);
}
