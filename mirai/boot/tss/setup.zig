//! TSS Setup

const common = @import("common");
const constants = @import("mirai").boot.constants;
const cpu = @import("asm").cpu;
const state = @import("mirai").boot.tss.state;

const layout = common.constants.memory.layout;
const limits = constants.tss.limits;
const sizes = common.constants.memory.sizes;

extern var __boot_ist_df_start: u8;
extern var __boot_ist_df_end: u8;
extern var __boot_ist_nmi_start: u8;
extern var __boot_ist_nmi_end: u8;
extern var __boot_ist_mc_start: u8;
extern var __boot_ist_mc_end: u8;
extern var __boot_ist_debug_start: u8;
extern var __boot_ist_debug_end: u8;

pub fn initializeBoot() bool {
    if (state.isInitialized()) return isBootReady();

    const stack_top = cpu.state.readStackPointer() & ~(limits.STACK_ALIGNMENT - 1);
    if (!isBootstrapStack(stack_top) or !areBootISTStacksValid()) return false;

    const boot_tss = state.getBootTSS();
    boot_tss.clear();
    boot_tss.setRSP0(stack_top);
    boot_tss.setIST(limits.IST_DOUBLE_FAULT, @intFromPtr(&__boot_ist_df_end));
    boot_tss.setIST(limits.IST_NMI, @intFromPtr(&__boot_ist_nmi_end));
    boot_tss.setIST(limits.IST_MACHINE_CHECK, @intFromPtr(&__boot_ist_mc_end));
    boot_tss.setIST(limits.IST_DEBUG, @intFromPtr(&__boot_ist_debug_end));
    state.setInitialized();
    return true;
}

pub fn isBootReady() bool {
    if (!state.isInitialized() or !areBootISTStacksValid()) return false;

    const boot_tss = state.getBootTSS();
    return isBootstrapStack(boot_tss.RSP0) and
        boot_tss.getIST(limits.IST_DOUBLE_FAULT) == @intFromPtr(&__boot_ist_df_end) and
        boot_tss.getIST(limits.IST_NMI) == @intFromPtr(&__boot_ist_nmi_end) and
        boot_tss.getIST(limits.IST_MACHINE_CHECK) == @intFromPtr(&__boot_ist_mc_end) and
        boot_tss.getIST(limits.IST_DEBUG) == @intFromPtr(&__boot_ist_debug_end);
}

fn isBootstrapStack(stack_top: u64) bool {
    return stack_top > layout.PHYSMAP_BASE and
        stack_top < layout.PHYSMAP_BASE + layout.PHYSMAP_MAX_SIZE and
        stack_top % limits.STACK_ALIGNMENT == 0;
}

fn isBootISTStackValid(stack_start: u64, stack_end: u64) bool {
    return stack_start >= layout.KERNEL_BASE and
        stack_end > stack_start and
        stack_end - stack_start == layout.BOOT_INTERRUPT_STACK_SIZE and
        stack_start % sizes.PAGE_SIZE == 0 and
        stack_end % sizes.PAGE_SIZE == 0;
}

fn areBootISTStacksValid() bool {
    return isBootISTStackValid(@intFromPtr(&__boot_ist_df_start), @intFromPtr(&__boot_ist_df_end)) and
        isBootISTStackValid(@intFromPtr(&__boot_ist_nmi_start), @intFromPtr(&__boot_ist_nmi_end)) and
        isBootISTStackValid(@intFromPtr(&__boot_ist_mc_start), @intFromPtr(&__boot_ist_mc_end)) and
        isBootISTStackValid(@intFromPtr(&__boot_ist_debug_start), @intFromPtr(&__boot_ist_debug_end));
}
