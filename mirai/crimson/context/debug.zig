//! Capture Debug Registers

const cpu = @import("asm").cpu;

const types = @import("mirai").crimson.types;

const DebugState = types.flavor.DebugState;

pub fn capture(state: *DebugState) void {
    state.DR0 = cpu.debug.readDR0();
    state.DR1 = cpu.debug.readDR1();
    state.DR2 = cpu.debug.readDR2();
    state.DR3 = cpu.debug.readDR3();
    state.DR6 = cpu.debug.readDR6();
    state.DR7 = cpu.debug.readDR7();
    state.DR4 = 0;
    state.DR5 = 0;
}

pub fn restore(state: *const DebugState) void {
    cpu.debug.writeDR0(state.DR0);
    cpu.debug.writeDR1(state.DR1);
    cpu.debug.writeDR2(state.DR2);
    cpu.debug.writeDR3(state.DR3);
    cpu.debug.writeDR6(state.DR6);
    cpu.debug.writeDR7(state.DR7);
}
