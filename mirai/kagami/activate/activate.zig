//! Validated Owned Kagami Activation

const common = @import("common");
const constants = @import("mirai").kagami.constants;
const cpu = @import("asm").cpu;
const create = @import("mirai").kagami.create;
const state = @import("mirai").kagami.state;
const synchronize = @import("mirai").kagami.synchronize;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const indices = common.constants.paging.indices;
const sizes = common.constants.memory.sizes;
const Kagami = types.kagami.Kagami;

pub fn activate(kagami: *Kagami) void {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    if (!state.hasOwnedKernel() or !tables.walk.isValidTable(kagami.PML4Physical) or
        (cpu.control.readCR4() & (cpu.constants.control.CR4_PCID_ENABLE | cpu.constants.control.CR4_LINEAR_ADDRESS_57_ENABLE)) != 0 or
        (cpu.control.readCR0() & cpu.constants.control.CR0_WRITE_PROTECT) == 0) return;
    if (!kagami.isKernel()) {
        if (!create.owns(kagami) or !kagami.SharesKernel) return;
        const root = tables.walk.getPML4(kagami.PML4Physical);
        const kernel = tables.walk.getPML4(state.getKernelKagami().PML4Physical);
        var index: usize = constants.tables.KERNEL_PML4_START;
        while (index < sizes.ENTRIES_PER_PAGE_TABLE) : (index += 1) {
            const shared = root.Entries[index];
            if (!shared.Present or shared.HugePage or shared.isOwnedTable() or shared.UserAccessible or
                (shared.AvailableLow & constants.ownership.SHARED_TABLE) == 0 or
                shared.getPhysicalAddress() != kernel.Entries[index].getPhysicalAddress()) return;
        }
    }
    cpu.control.flushAllTLB();
    cpu.control.writeCR3(kagami.PML4Physical);
    state.setCurrentKagami(kagami);
}

pub fn activateKernel() void {
    activate(state.getKernelKagami());
}

pub fn getActivePML4() u64 {
    return cpu.control.readCR3() & indices.ADDRESS_MASK;
}

pub fn isActive(kagami: *const Kagami) bool {
    return getActivePML4() == kagami.PML4Physical;
}
