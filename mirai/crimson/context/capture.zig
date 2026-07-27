//! Capture CPU Context

const cpu = @import("asm").cpu;
const gdt = @import("asm").gdt;

const types = @import("../types/types.zig");

const Context = types.context.Context;
const Frame = types.frame.Frame;

pub fn captureFromFrame(context: *Context, frame: *const Frame) void {
    context.RIP = frame.RIP;
    context.CS = @truncate(frame.CS);
    context.RFLAGS = frame.RFLAGS;
    context.RSP = frame.RSP;
    context.SS = @truncate(frame.SS);
    context.CR0 = cpu.control.readCR0();
    context.CR2 = cpu.control.readCR2();
    context.CR3 = cpu.control.readCR3();
    context.CR4 = cpu.control.readCR4();
}

pub fn captureSegments(context: *Context) void {
    context.DS = gdt.segment.readDataSegment();
    context.ES = gdt.segment.readExtraSegment();
    context.FS = gdt.segment.readFsSegment();
    context.GS = gdt.segment.readGsSegment();
}
