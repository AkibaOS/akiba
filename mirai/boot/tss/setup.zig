//! TSS Setup

const common = @import("common");

const constants = @import("mirai").boot.constants;
const stacks = @import("mirai").boot.tss.stacks;
const state = @import("mirai").boot.tss.state;
const types = @import("mirai").boot.types;

const limits = constants.tss.limits;

const AllocationError = common.errors.memory.allocation.AllocationError;
const CoreTSS = types.tss.core.CoreTSS;
const TSS = types.tss.structure.TSS;

pub const CoreError = AllocationError || error{TooManyCores};

pub fn initializeBoot() void {
    const boot_tss = state.getBootTSS();
    boot_tss.clear();
    state.setInitialized();
}

pub fn initializeCore(core_id: u16, kernel_stack_top: u64) CoreError!*CoreTSS {
    const core_tss = state.registerCore(core_id) orelse return CoreError.TooManyCores;

    core_tss.TSS.clear();
    core_tss.TSS.setRSP0(kernel_stack_top);

    try setupCoreTSS(core_tss);

    return core_tss;
}

pub fn setupCoreTSS(core_tss: *CoreTSS) AllocationError!void {
    const kernel_stack = try stacks.allocateKernelStack();
    core_tss.setKernelStack(kernel_stack.Base, limits.DEFAULT_STACK_SIZE);

    const double_fault_stack = try stacks.allocateISTStack();
    core_tss.setISTStack(limits.IST_DOUBLE_FAULT, double_fault_stack.Base, limits.INTERRUPT_STACK_SIZE);

    const nmi_stack = try stacks.allocateISTStack();
    core_tss.setISTStack(limits.IST_NMI, nmi_stack.Base, limits.INTERRUPT_STACK_SIZE);

    const machine_check_stack = try stacks.allocateISTStack();
    core_tss.setISTStack(limits.IST_MACHINE_CHECK, machine_check_stack.Base, limits.INTERRUPT_STACK_SIZE);

    const debug_stack = try stacks.allocateISTStack();
    core_tss.setISTStack(limits.IST_DEBUG, debug_stack.Base, limits.INTERRUPT_STACK_SIZE);
}

pub fn setupMinimalTSS(tss: *TSS, kernel_stack_top: u64) void {
    tss.clear();
    tss.setRSP0(kernel_stack_top);
}
