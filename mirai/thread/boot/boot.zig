//! Existing Kernel Execution Adoption

const cpu = @import("asm").cpu;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const stack = @import("mirai").memory.stack;
const state = @import("mirai").thread.state;
const synchronize = @import("mirai").kagami.synchronize;
const tss = @import("mirai").boot.tss;

pub fn initialize() bool {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    if (state.getCurrent() != null or !tss.state.isInitialized() or tss.state.getCoreCount() != 0) return false;
    const stacks = stack.state.getState();
    const pointer = cpu.state.readStackPointer();
    if (stacks.BootStackBase == 0 or stacks.BootStackTop <= stacks.BootStackBase or
        pointer < stacks.BootStackBase or pointer >= stacks.BootStackTop or
        tss.state.getBootTSS().RSP0 != stacks.BootStackTop or
        !kagami.activate.isActive(kagami.state.getKernelKagami())) return false;
    if (kata.state.getKernel() == null and !kata.state.initializeKernel()) return false;
    const owner = kata.state.getKernel() orelse return false;
    return state.initializeBoot(owner, .{ .Base = stacks.BootStackBase, .Top = stacks.BootStackTop });
}
