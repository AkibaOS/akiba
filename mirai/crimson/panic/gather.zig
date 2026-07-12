//! Gather System State

const asm_cpu = @import("asm").cpu;
const types = @import("../types/types.zig");
const context_ops = @import("../context/context.zig");

const Context = types.Context;
const FloatState = types.FloatState;
const DebugState = types.DebugState;

pub fn capture_current_context(context: *Context) void {
    context.clear();

    context.cr0 = asm_cpu.read_cr0();
    context.cr2 = asm_cpu.read_cr2();
    context.cr3 = asm_cpu.read_cr3();
    context.cr4 = asm_cpu.read_cr4();

    context.rflags = asm_cpu.read_flags();
    context.rsp = asm_cpu.read_rsp();

    context_ops.capture_segments(context);
}

pub fn capture_float_state(state: *FloatState) void {
    context_ops.capture_float(state);
}

pub fn capture_debug_state(state: *DebugState) void {
    context_ops.capture_debug(state);
}

pub fn get_current_cpu() u32 {
    return 0;
}

pub fn get_uptime_ticks() u64 {
    return asm_cpu.rdtsc();
}
