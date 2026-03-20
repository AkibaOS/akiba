//! Capture CPU Context

const asm_cpu = @import("../../asm/cpu/cpu.zig");
const types = @import("../types/types.zig");
const Context = types.Context;
const Frame = types.Frame;

pub fn capture_from_frame(context: *Context, frame: *const Frame) void {
    context.rip = frame.rip;
    context.cs = @truncate(frame.cs);
    context.rflags = frame.rflags;
    context.rsp = frame.rsp;
    context.ss = @truncate(frame.ss);
    context.cr0 = asm_cpu.read_cr0();
    context.cr2 = asm_cpu.read_cr2();
    context.cr3 = asm_cpu.read_cr3();
    context.cr4 = asm_cpu.read_cr4();
}

pub fn capture_segments(context: *Context) void {
    context.ds = asm_cpu.read_ds();
    context.es = asm_cpu.read_es();
    context.fs = asm_cpu.read_fs();
    context.gs = asm_cpu.read_gs();
}
