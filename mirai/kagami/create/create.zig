//! Create Kagami

const common = @import("common");

const constants = @import("mirai").kagami.constants;
const pmm = @import("mirai").pmm;
const state = @import("mirai").kagami.state;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const bits = @import("utils").bits;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Kagami = types.kagami.Kagami;
const pool = constants.pool;

var kagami_pool: [pool.MAX_KAGAMI]Kagami = undefined;
var kagami_pool_bitmap: [pool.POOL_BITMAP_BYTES]u8 = [_]u8{0} ** pool.POOL_BITMAP_BYTES;

pub fn create() AllocationError!*Kagami {
    const pml4_physical = try pmm.allocate.single.allocatePageZeroed();

    const kagami = allocateKagamiStruct() orelse {
        pmm.free.single.freePage(pml4_physical);
        return AllocationError.OutOfMemory;
    };

    kagami.* = Kagami{
        .PML4Physical = pml4_physical,
        .ReferenceCount = 1,
        .ResidentPages = 0,
        .WiredPages = 0,
        .TablePages = 1,
        .Lock = false,
    };

    const kernel_kagami = state.getKernelKagami();
    const new_pml4 = tables.walk.getPML4(pml4_physical);
    const kernel_pml4 = tables.walk.getPML4(kernel_kagami.PML4Physical);

    new_pml4.copyKernelEntries(kernel_pml4);

    return kagami;
}

fn allocateKagamiStruct() ?*Kagami {
    const free_index = bits.operations.findFirstClear(&kagami_pool_bitmap, 0, pool.MAX_KAGAMI) orelse return null;
    bits.operations.setBit(&kagami_pool_bitmap, free_index);
    return &kagami_pool[free_index];
}

pub fn freeKagamiStruct(kagami: *Kagami) void {
    const base_pointer: usize = @intFromPtr(&kagami_pool[0]);
    const kagami_pointer: usize = @intFromPtr(kagami);

    if (kagami_pointer < base_pointer) return;

    const offset = kagami_pointer - base_pointer;
    const index = offset / @sizeOf(Kagami);

    if (index >= pool.MAX_KAGAMI) return;

    bits.operations.clearBit(&kagami_pool_bitmap, index);
}
