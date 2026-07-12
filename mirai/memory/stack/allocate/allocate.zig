//! Kernel Stack Allocation

const common = @import("root").common;
const kagami = @import("../../../kagami/kagami.zig");
const pmm = @import("../../../pmm/pmm.zig");
const constants = @import("../../constants/stack/stack.zig");
const state = @import("../state.zig");
const types = @import("../../types/stack/stack.zig");

const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.AllocationError;
const MappingError = common.errors.memory.MappingError;

const KernelStack = types.KernelStack;

pub const StackError = AllocationError || MappingError;

pub fn allocate() StackError!KernelStack {
    const allocator_state = state.get_state();

    if (allocator_state.free_list) |node| {
        allocator_state.free_list = node.next;
        allocator_state.free_count -= 1;
        const stack_base = @intFromPtr(node);
        return KernelStack{
            .base = stack_base,
            .top = stack_base + constants.stack_size,
        };
    }

    return create();
}

fn create() StackError!KernelStack {
    const allocator_state = state.get_state();

    if (allocator_state.next_slot >= constants.max_slots) {
        return AllocationError.RegionExhausted;
    }

    const slot_base = constants.area_base + allocator_state.next_slot * constants.slot_size;
    const stack_base = slot_base + constants.guard_pages * sizes.page_size;
    const kernel_kagami = kagami.kernel();

    var mapped_pages: u64 = 0;
    errdefer unwind(kernel_kagami, stack_base, mapped_pages);

    while (mapped_pages < constants.stack_pages) {
        const physical_page = try pmm.allocate_page();
        const virtual_address = stack_base + mapped_pages * sizes.page_size;

        kagami.enter(
            kernel_kagami,
            virtual_address,
            physical_page,
            kagami.constants.protection.kernel_write | kagami.constants.protection.wired,
        ) catch |mapping_error| {
            pmm.free_page(physical_page);
            return mapping_error;
        };

        mapped_pages += 1;
    }

    allocator_state.next_slot += 1;
    allocator_state.total_count += 1;
    if (allocator_state.total_count > allocator_state.high_watermark) {
        allocator_state.high_watermark = allocator_state.total_count;
    }

    return KernelStack{
        .base = stack_base,
        .top = stack_base + constants.stack_size,
    };
}

fn unwind(kernel_kagami: *kagami.Kagami, stack_base: u64, mapped_pages: u64) void {
    var page_index: u64 = 0;
    while (page_index < mapped_pages) : (page_index += 1) {
        const virtual_address = stack_base + page_index * sizes.page_size;
        if (kagami.remove(kernel_kagami, virtual_address)) |physical_page| {
            pmm.free_page(physical_page);
        }
    }
}
