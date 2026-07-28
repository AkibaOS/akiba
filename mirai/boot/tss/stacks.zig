//! TSS Stack Allocation

const common = @import("common");

const constants = @import("mirai").boot.constants;
const pmm = @import("mirai").pmm;

const address = @import("utils").address;

const limits = constants.tss.limits;
const sizes = common.constants.memory.sizes;

const AllocationError = common.errors.memory.allocation.AllocationError;

pub const StackRange = struct {
    Base: u64,
    Top: u64,
};

pub fn allocateKernelStack() AllocationError!StackRange {
    return allocateStack(limits.DEFAULT_STACK_SIZE);
}

pub fn allocateISTStack() AllocationError!StackRange {
    return allocateStack(limits.INTERRUPT_STACK_SIZE);
}

fn allocateStack(size: u64) AllocationError!StackRange {
    const page_count = size / sizes.PAGE_SIZE;
    const physical_base = try pmm.allocate.contiguous.allocateContiguous(page_count);
    const virtual_base = address.translate.physToVirt(physical_base);

    return StackRange{
        .Base = virtual_base,
        .Top = virtual_base + size,
    };
}

pub fn freeStack(base: u64, size: u64) void {
    const physical_base = address.translate.virtToPhys(base);
    const page_count = size / sizes.PAGE_SIZE;
    pmm.free.range.freeRange(physical_base, page_count);
}
