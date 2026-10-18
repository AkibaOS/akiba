//! Interrupt Handler Stub Builders

const std = @import("std");

const constants = @import("asm").interrupts.constants;
const fpu = @import("asm").cpu.constants.fpu;
const strings = @import("asm").interrupts.strings;

pub fn pushVector(comptime vector: u8) []const u8 {
    return comptime std.fmt.comptimePrint(strings.stubs.PUSH_VECTOR_FORMAT, .{vector});
}

fn saveDispatch() []const u8 {
    return comptime std.fmt.comptimePrint(strings.stubs.SAVE_DISPATCH_FORMAT, .{
        constants.dispatch.STACK_SIZE,
        fpu.DEFAULT_MXCSR,
        constants.dispatch.KERNEL_MXCSR_OFFSET,
        constants.dispatch.KERNEL_MXCSR_OFFSET,
    });
}

fn restoreDispatch() []const u8 {
    return comptime std.fmt.comptimePrint(strings.stubs.RESTORE_DISPATCH_FORMAT, .{constants.dispatch.STACK_SIZE});
}

pub fn exceptionStub(comptime vector: u8, comptime has_error_code: bool) []const u8 {
    return (if (!has_error_code) strings.stubs.PUSH_ZERO else strings.stubs.EMPTY) ++
        pushVector(vector) ++
        strings.stubs.PUSH_ALL ++ strings.stubs.NEWLINE ++
        saveDispatch() ++ strings.stubs.NEWLINE ++
        strings.stubs.CALL_EXCEPTION_DISPATCH ++ strings.stubs.NEWLINE ++
        restoreDispatch() ++ strings.stubs.NEWLINE ++
        strings.stubs.POP_ALL ++ strings.stubs.NEWLINE ++
        strings.stubs.IRET_CLEANUP;
}

pub fn irqStub(comptime irq: u8) []const u8 {
    return strings.stubs.PUSH_ZERO ++
        pushVector(irq + constants.vectors.VECTOR_OFFSET) ++
        strings.stubs.PUSH_ALL ++ strings.stubs.NEWLINE ++
        saveDispatch() ++ strings.stubs.NEWLINE ++
        strings.stubs.CALL_IRQ_DISPATCH ++ strings.stubs.NEWLINE ++
        restoreDispatch() ++ strings.stubs.NEWLINE ++
        strings.stubs.POP_ALL ++ strings.stubs.NEWLINE ++
        strings.stubs.IRET_CLEANUP;
}

pub fn makeExceptionHandler(comptime vector: u8, comptime has_error_code: bool) fn () callconv(.naked) void {
    return struct {
        fn handler() callconv(.naked) void {
            asm volatile (exceptionStub(vector, has_error_code));
        }
    }.handler;
}

pub fn makeIRQHandler(comptime irq: u8) fn () callconv(.naked) void {
    return struct {
        fn handler() callconv(.naked) void {
            asm volatile (irqStub(irq));
        }
    }.handler;
}
