//! Create Kagami

const common = @import("../../../common/common.zig");
const pmm = @import("../../pmm/pmm.zig");
const types = @import("../types/types.zig");
const state = @import("../state.zig");
const tables = @import("../tables/tables.zig");

const AllocationError = common.errors.memory.AllocationError;
const Kagami = types.Kagami;
const Table = types.Table;

var kagami_pool: [256]Kagami = undefined;
var kagami_pool_bitmap: [32]u8 = [_]u8{0} ** 32;

pub fn create() AllocationError!*Kagami {
    const pml4_physical = try pmm.allocate_page_zeroed();

    const kagami = allocate_kagami_struct() orelse {
        pmm.free_page(pml4_physical);
        return AllocationError.OutOfMemory;
    };

    kagami.* = Kagami{
        .pml4_physical = pml4_physical,
        .reference_count = 1,
        .resident_pages = 0,
        .wired_pages = 0,
        .table_pages = 1,
        .lock = false,
    };

    const kernel_kagami = state.get_kernel_kagami();
    const new_pml4 = tables.get_pml4(pml4_physical);
    const kernel_pml4 = tables.get_pml4(kernel_kagami.pml4_physical);

    new_pml4.copy_kernel_entries(kernel_pml4);

    return kagami;
}

fn allocate_kagami_struct() ?*Kagami {
    var index: usize = 0;
    while (index < 256) : (index += 1) {
        const byte_index = index / 8;
        const bit_index: u3 = @truncate(index % 8);

        if ((kagami_pool_bitmap[byte_index] & (@as(u8, 1) << bit_index)) == 0) {
            kagami_pool_bitmap[byte_index] |= (@as(u8, 1) << bit_index);
            return &kagami_pool[index];
        }
    }
    return null;
}

pub fn free_kagami_struct(kagami: *Kagami) void {
    const base_ptr: usize = @intFromPtr(&kagami_pool[0]);
    const kagami_ptr: usize = @intFromPtr(kagami);

    if (kagami_ptr < base_ptr) return;

    const offset = kagami_ptr - base_ptr;
    const index = offset / @sizeOf(Kagami);

    if (index >= 256) return;

    const byte_index = index / 8;
    const bit_index: u3 = @truncate(index % 8);

    kagami_pool_bitmap[byte_index] &= ~(@as(u8, 1) << bit_index);
}
