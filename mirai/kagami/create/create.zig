//! Owned User Root Creation

const bits = @import("utils").bits;
const common = @import("common");
const constants = @import("mirai").kagami.constants;
const state = @import("mirai").kagami.state;
const synchronize = @import("mirai").kagami.synchronize;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Kagami = types.kagami.Kagami;
const pool = constants.pool;

var kagami_pool: [pool.MAX_KAGAMI]Kagami = [_]Kagami{.{}} ** pool.MAX_KAGAMI;
var kagami_pool_bitmap: [pool.POOL_BITMAP_BYTES]u8 = [_]u8{0} ** pool.POOL_BITMAP_BYTES;

pub fn create() AllocationError!*Kagami {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    if (!state.hasOwnedKernel()) return AllocationError.NotInitialized;
    const kernel_kagami = state.getKernelKagami();
    if (!tables.walk.isValidTable(kernel_kagami.PML4Physical)) return AllocationError.NotInitialized;
    const kernel_pml4 = tables.walk.getPML4(kernel_kagami.PML4Physical);
    for (kernel_pml4.Entries[constants.tables.KERNEL_PML4_START..]) |entry| {
        if (!entry.Present or entry.HugePage or !entry.isOwnedTable() or entry.UserAccessible or
            !tables.walk.isValidTable(entry.getPhysicalAddress())) return AllocationError.NotInitialized;
    }
    const index = bits.operations.findFirstClear(&kagami_pool_bitmap, 0, pool.MAX_KAGAMI) orelse return AllocationError.OutOfMemory;
    const pml4_physical = try tables.allocate.allocateTable();
    const kagami = &kagami_pool[index];
    kagami.* = .{
        .PML4Physical = pml4_physical,
        .TablePages = 1,
        .Ownership = .User,
        .SharesKernel = true,
    };
    tables.walk.getPML4(pml4_physical).copyKernelEntries(kernel_pml4);
    bits.operations.setBit(&kagami_pool_bitmap, index);
    return kagami;
}

fn poolIndex(kagami: *const Kagami) ?usize {
    const base_pointer = @intFromPtr(&kagami_pool[0]);
    const pointer = @intFromPtr(kagami);
    if (pointer < base_pointer) return null;
    const offset = pointer - base_pointer;
    if (offset % @sizeOf(Kagami) != 0) return null;
    const index = offset / @sizeOf(Kagami);
    if (index >= pool.MAX_KAGAMI) return null;
    return index;
}

pub fn owns(kagami: *const Kagami) bool {
    const index = poolIndex(kagami) orelse return false;
    return bits.operations.testBit(&kagami_pool_bitmap, index) and kagami.Ownership == .User and
        kagami.ReferenceCount != 0 and tables.walk.isValidTable(kagami.PML4Physical);
}

pub fn freeKagamiStruct(kagami: *Kagami) void {
    const index = poolIndex(kagami) orelse return;
    if (kagami.PML4Physical != 0 or kagami.ReferenceCount != 0) return;
    kagami.* = .{};
    bits.operations.clearBit(&kagami_pool_bitmap, index);
}
