//! Owned User Root Creation

const common = @import("common");
const constants = @import("mirai").kagami.constants;
const guard = @import("asm").interrupts.guard;
const labels = @import("mirai").kagami.strings.pool;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const state = @import("mirai").kagami.state;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Kagami = types.kagami.Kagami;
const RecordStore = memory.types.pool.store.create(Kagami);

var records: RecordStore = .{};

pub fn create() AllocationError!*Kagami {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!state.hasOwnedKernel()) return AllocationError.NotInitialized;
    const kernel = state.getKernelKagami();
    if (!tables.walk.isValidTable(kernel.PML4Physical)) return AllocationError.NotInitialized;
    const kernel_pml4 = tables.walk.getPML4(kernel.PML4Physical);
    for (kernel_pml4.Entries[constants.tables.geometry.KERNEL_PML4_START..]) |entry| {
        if (!entry.Present or entry.HugePage or !entry.isOwnedTable() or entry.UserAccessible or
            !tables.walk.isValidTable(entry.getPhysicalAddress())) return AllocationError.NotInitialized;
    }
    const search = pmm.state.getState().SearchStart;
    errdefer pmm.state.getState().SearchStart = search;
    const root = try records.reserveNamed(labels.DESCRIPTORS);
    errdefer {
        if (!records.release(root)) unreachable;
        _ = records.collectAt(root);
        records.pruneEmpty();
    }
    root.* = .{ .Ownership = .User, .SharesKernel = true };
    root.PML4Physical = try tables.allocate.allocateTable(root);
    tables.walk.getPML4(root.PML4Physical).copyKernelEntries(kernel_pml4);
    return root;
}

pub fn owns(root: *const Kagami) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(root)) return false;
    return root.Ownership == .User and root.ReferenceCount != 0 and tables.walk.isValidTable(root.PML4Physical) and
        tables.ownership.owns(root, root.PML4Physical);
}

pub fn freeKagamiStruct(root: *Kagami) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(root)) return false;
    if (root.PML4Physical != 0 or root.ReferenceCount != 0 or root.ExecutionOwners != 0 or root.TablePages != 0 or root.Frames != null) return false;
    if (!records.release(root)) return false;
    _ = records.collectAt(root);
    records.pruneEmpty();
    return true;
}
