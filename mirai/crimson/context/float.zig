//! Capture Floating Point State

const asm_fpu = @import("../../asm/fpu/fpu.zig");
const types = @import("../types/types.zig");
const FloatState = types.FloatState;

pub fn capture(state: *FloatState) void {
    asm_fpu.fxsave(@intFromPtr(state));
}

pub fn restore(state: *const FloatState) void {
    asm_fpu.fxrstor(@intFromPtr(state));
}

pub fn init_fpu() void {
    asm_fpu.fninit();
}
