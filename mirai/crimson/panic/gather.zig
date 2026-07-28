//! Gather System State

const cpu = @import("asm").cpu;

const context = @import("mirai").crimson.context;
const types = @import("mirai").crimson.types;

const Context = types.context.Context;
const DebugState = types.flavor.DebugState;
const FloatState = types.flavor.FloatState;

pub fn captureCurrentContext(target: *Context) void {
    target.clear();

    target.CR0 = cpu.control.readCR0();
    target.CR2 = cpu.control.readCR2();
    target.CR3 = cpu.control.readCR3();
    target.CR4 = cpu.control.readCR4();

    target.RFLAGS = cpu.state.readFlags();
    target.RSP = cpu.state.readStackPointer();

    context.capture.captureSegments(target);
}

pub fn captureFloatState(state: *FloatState) void {
    context.float.capture(state);
}

pub fn captureDebugState(state: *DebugState) void {
    context.debug.capture(state);
}

pub fn getCurrentCPU() u32 {
    return 0;
}

pub fn getUptimeTicks() u64 {
    return cpu.state.readTimeStampCounter();
}
