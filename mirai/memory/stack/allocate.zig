//! Reusable Guarded Kernel Stack Allocation

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const limits = @import("mirai").memory.constants.stack.limits;
const mapping = @import("mirai").memory.stack.mapping;
const pmm = @import("mirai").pmm;
const state = @import("mirai").memory.stack.state;
const types = @import("mirai").memory.types;

const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.allocation.AllocationError;
const MappingError = common.errors.memory.mapping.MappingError;
const KernelStack = types.stack.kernel.KernelStack;

pub fn allocate() (AllocationError || MappingError)!KernelStack {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!kagami.state.hasOwnedKernel()) return AllocationError.NotInitialized;
    if (state.getState().FreeList) |cached| {
        if (!mapping.validate(cached)) return AllocationError.InvalidSize;
        if (state.takeCached()) |record| return record.Stack;
    }
    return create();
}

fn create() (AllocationError || MappingError)!KernelStack {
    const search = pmm.state.getState().SearchStart;
    errdefer pmm.state.getState().SearchStart = search;
    const record = try state.reserve();
    errdefer {
        mapping.unwind(record);
        state.discard(record);
    }
    while (record.PageCount < limits.STACK_PAGES) {
        const index = record.PageCount;
        const physical = try pmm.allocate.single.allocatePageZeroed();
        record.Pages[index] = physical;
        kagami.enter.enter(kagami.state.getKernelKagami(), record.Stack.Base + index * sizes.PAGE_SIZE, physical, kagami.constants.protection.KERNEL_WRITE | kagami.constants.protection.WIRED) catch |failure| {
            pmm.free.single.freePage(physical);
            record.Pages[index] = 0;
            return failure;
        };
        record.PageCount += 1;
    }
    if (!state.publish(record)) return AllocationError.RegionExhausted;
    return record.Stack;
}
