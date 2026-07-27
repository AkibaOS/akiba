//! Capture Floating Point State

const cpu = @import("asm").cpu;

const types = @import("../types/types.zig");

const FloatState = types.flavor.FloatState;

pub fn capture(state: *FloatState) void {
    cpu.fpu.saveFpuState(@intFromPtr(state));
}

pub fn restore(state: *const FloatState) void {
    cpu.fpu.restoreFpuState(@intFromPtr(state));
}

pub fn initializeFpu() void {
    cpu.fpu.initializeFpu();
}
