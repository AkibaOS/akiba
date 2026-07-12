//! TSS Setup

const types = @import("../../types/tss/tss.zig");
const constants = @import("../../constants/tss/tss.zig");
const stacks = @import("../stacks/stacks.zig");
const common = @import("root").common;

const CoreTss = types.CoreTss;
const Tss = types.Tss;
const AllocationError = common.errors.memory.AllocationError;

pub fn setup_core_tss(core_tss: *CoreTss) AllocationError!void {
    const kernel_stack = try stacks.allocate_kernel_stack();
    core_tss.set_kernel_stack(kernel_stack.base, constants.default_stack_size);

    const ist1_stack = try stacks.allocate_ist_stack();
    core_tss.set_ist_stack(constants.ist_double_fault, ist1_stack.base, constants.interrupt_stack_size);

    const ist2_stack = try stacks.allocate_ist_stack();
    core_tss.set_ist_stack(constants.ist_nmi, ist2_stack.base, constants.interrupt_stack_size);

    const ist3_stack = try stacks.allocate_ist_stack();
    core_tss.set_ist_stack(constants.ist_machine_check, ist3_stack.base, constants.interrupt_stack_size);

    const ist4_stack = try stacks.allocate_ist_stack();
    core_tss.set_ist_stack(constants.ist_debug, ist4_stack.base, constants.interrupt_stack_size);
}

pub fn setup_minimal_tss(tss: *Tss, kernel_stack_top: u64) void {
    tss.clear();
    tss.set_rsp0(kernel_stack_top);
}
