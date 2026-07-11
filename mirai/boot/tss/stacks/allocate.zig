//! TSS Stack Allocation

const pmm = @import("../../../pmm/pmm.zig");
const common = @import("root").common;
const constants = @import("../constants/constants.zig");

const memory_layout = common.constants.memory.layout;
const AllocationError = common.errors.memory.AllocationError;

pub fn allocate_kernel_stack() AllocationError!struct { base: u64, top: u64 } {
    const page_count = constants.default_stack_size / 4096;
    const physical_base = try pmm.allocate_contiguous(page_count);
    const virtual_base = physical_base + memory_layout.physmap_base;
    const stack_top = virtual_base + constants.default_stack_size;

    return .{
        .base = virtual_base,
        .top = stack_top,
    };
}

pub fn allocate_ist_stack() AllocationError!struct { base: u64, top: u64 } {
    const page_count = constants.interrupt_stack_size / 4096;
    const physical_base = try pmm.allocate_contiguous(page_count);
    const virtual_base = physical_base + memory_layout.physmap_base;
    const stack_top = virtual_base + constants.interrupt_stack_size;

    return .{
        .base = virtual_base,
        .top = stack_top,
    };
}

pub fn free_stack(base: u64, size: u64) void {
    const physical_base = base - memory_layout.physmap_base;
    const page_count = size / 4096;
    pmm.free_range(physical_base, page_count);
}
