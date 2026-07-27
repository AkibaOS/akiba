//! Kernel Stack Allocation

const common = @import("common");

const constants = @import("../constants/constants.zig");
const kagami = @import("../../kagami/kagami.zig");
const pmm = @import("../../pmm/pmm.zig");
const state = @import("state.zig");
const types = @import("../types/types.zig");

const limits = constants.stack.limits;
const sizes = common.constants.memory.sizes;

const AllocationError = common.errors.memory.allocation.AllocationError;
const MappingError = common.errors.memory.mapping.MappingError;

const Kagami = kagami.types.kagami.Kagami;
const KernelStack = types.stack.kernel.KernelStack;

pub const StackError = AllocationError || MappingError;

pub fn allocate() StackError!KernelStack {
    const allocator_state = state.getState();

    if (allocator_state.FreeList) |node| {
        allocator_state.FreeList = node.Next;
        allocator_state.FreeCount -= 1;
        const stack_base = @intFromPtr(node);
        return KernelStack{
            .Base = stack_base,
            .Top = stack_base + limits.STACK_SIZE,
        };
    }

    return create();
}

fn create() StackError!KernelStack {
    const allocator_state = state.getState();

    if (allocator_state.NextSlot >= limits.MAX_SLOTS) {
        return AllocationError.RegionExhausted;
    }

    const slot_base = limits.AREA_BASE + allocator_state.NextSlot * limits.SLOT_SIZE;
    const stack_base = slot_base + limits.GUARD_PAGES * sizes.PAGE_SIZE;
    const kernel_kagami = kagami.state.getKernelKagami();

    var mapped_pages: u64 = 0;
    errdefer unwind(kernel_kagami, stack_base, mapped_pages);

    while (mapped_pages < limits.STACK_PAGES) {
        const physical_page = try pmm.allocate.single.allocatePage();
        const virtual_address = stack_base + mapped_pages * sizes.PAGE_SIZE;

        kagami.enter.enter(
            kernel_kagami,
            virtual_address,
            physical_page,
            kagami.constants.protection.KERNEL_WRITE | kagami.constants.protection.WIRED,
        ) catch |mapping_error| {
            pmm.free.single.freePage(physical_page);
            return mapping_error;
        };

        mapped_pages += 1;
    }

    allocator_state.NextSlot += 1;
    allocator_state.TotalCount += 1;
    if (allocator_state.TotalCount > allocator_state.HighWatermark) {
        allocator_state.HighWatermark = allocator_state.TotalCount;
    }

    return KernelStack{
        .Base = stack_base,
        .Top = stack_base + limits.STACK_SIZE,
    };
}

fn unwind(kernel_kagami: *Kagami, stack_base: u64, mapped_pages: u64) void {
    var page_index: u64 = 0;
    while (page_index < mapped_pages) : (page_index += 1) {
        const virtual_address = stack_base + page_index * sizes.PAGE_SIZE;
        if (kagami.remove.remove(kernel_kagami, virtual_address)) |physical_page| {
            pmm.free.single.freePage(physical_page);
        }
    }
}
