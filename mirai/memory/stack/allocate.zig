//! Kernel Stack Allocation

const bits = @import("utils").bits;
const common = @import("common");
const constants = @import("mirai").memory.constants;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const pmm = @import("mirai").pmm;
const state = @import("mirai").memory.stack.state;
const types = @import("mirai").memory.types;

const limits = constants.stack.limits;
const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.allocation.AllocationError;
const MappingError = common.errors.memory.mapping.MappingError;
const Kagami = kagami.types.kagami.Kagami;
const KernelStack = types.stack.kernel.KernelStack;

pub fn allocate() (AllocationError || MappingError)!KernelStack {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!kagami.state.hasOwnedKernel()) return AllocationError.NotInitialized;
    const allocator_state = state.getState();
    while (allocator_state.FreeList) |node| {
        const stack_base = @intFromPtr(node);
        if (state.isPinned(stack_base)) break;
        allocator_state.FreeList = node.Next;
        allocator_state.FreeCount -= 1;
        bits.operations.setBit(&allocator_state.AllocatedSlots, (stack_base - limits.AREA_BASE) / limits.SLOT_SIZE);
        return .{ .Base = stack_base, .Top = stack_base + limits.STACK_SIZE };
    }
    return create();
}

fn create() (AllocationError || MappingError)!KernelStack {
    const allocator_state = state.getState();
    if (allocator_state.NextSlot >= limits.MAX_SLOTS) return AllocationError.RegionExhausted;
    const slot_base = limits.AREA_BASE + allocator_state.NextSlot * limits.SLOT_SIZE;
    const stack_base = slot_base + limits.GUARD_PAGES * sizes.PAGE_SIZE;
    const kernel_kagami = kagami.state.getKernelKagami();
    var mapped_pages: u64 = 0;
    errdefer unwind(kernel_kagami, stack_base, mapped_pages);
    while (mapped_pages < limits.STACK_PAGES) : (mapped_pages += 1) {
        const physical_page = try pmm.allocate.single.allocatePageZeroed();
        kagami.enter.enter(
            kernel_kagami,
            stack_base + mapped_pages * sizes.PAGE_SIZE,
            physical_page,
            kagami.constants.protection.KERNEL_WRITE | kagami.constants.protection.WIRED,
        ) catch |mapping_error| {
            pmm.free.single.freePage(physical_page);
            return mapping_error;
        };
    }
    bits.operations.setBit(&allocator_state.AllocatedSlots, allocator_state.NextSlot);
    allocator_state.NextSlot += 1;
    allocator_state.TotalCount += 1;
    allocator_state.HighWatermark = @max(allocator_state.HighWatermark, allocator_state.TotalCount);
    return .{ .Base = stack_base, .Top = stack_base + limits.STACK_SIZE };
}

fn unwind(kernel_kagami: *Kagami, stack_base: u64, mapped_pages: u64) void {
    var page_index: u64 = 0;
    while (page_index < mapped_pages) : (page_index += 1) {
        if (kagami.remove.remove(kernel_kagami, stack_base + page_index * sizes.PAGE_SIZE)) |physical_page| {
            pmm.free.single.freePage(physical_page);
        }
    }
}
