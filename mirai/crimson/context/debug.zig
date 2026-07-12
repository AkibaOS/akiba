//! Capture Debug Registers

const asm_debug = @import("asm").debug;
const types = @import("../types/types.zig");
const DebugState = types.DebugState;

pub fn capture(state: *DebugState) void {
    state.dr0 = asm_debug.read_dr0();
    state.dr1 = asm_debug.read_dr1();
    state.dr2 = asm_debug.read_dr2();
    state.dr3 = asm_debug.read_dr3();
    state.dr6 = asm_debug.read_dr6();
    state.dr7 = asm_debug.read_dr7();
    state.dr4 = 0;
    state.dr5 = 0;
}

pub fn restore(state: *const DebugState) void {
    asm_debug.write_dr0(state.dr0);
    asm_debug.write_dr1(state.dr1);
    asm_debug.write_dr2(state.dr2);
    asm_debug.write_dr3(state.dr3);
    asm_debug.write_dr6(state.dr6);
    asm_debug.write_dr7(state.dr7);
}
