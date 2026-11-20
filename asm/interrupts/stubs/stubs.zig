//! Interrupt Handler Stub Builders

const std = @import("std");

const constants = @import("asm").interrupts.constants;
const fpu = @import("asm").cpu.constants.fpu.state;
const strings = @import("asm").interrupts.strings;
const vectors = @import("common").constants.interrupts.vectors;

pub fn pushVector(comptime vector: u8) []const u8 {
    return comptime std.fmt.comptimePrint(strings.stubs.templates.PUSH_VECTOR_FORMAT, .{vector});
}

fn saveDispatch() []const u8 {
    return comptime std.fmt.comptimePrint(strings.stubs.templates.SAVE_DISPATCH_FORMAT, .{
        constants.dispatch.STACK_SIZE,
        fpu.DEFAULT_MXCSR,
        constants.dispatch.KERNEL_MXCSR_OFFSET,
        constants.dispatch.KERNEL_MXCSR_OFFSET,
    });
}

fn restoreDispatch() []const u8 {
    return comptime std.fmt.comptimePrint(strings.stubs.templates.RESTORE_DISPATCH_FORMAT, .{constants.dispatch.STACK_SIZE});
}

pub fn exceptionStub(comptime vector: u8, comptime has_error_code: bool) []const u8 {
    return (if (!has_error_code) strings.stubs.templates.PUSH_ZERO else strings.stubs.templates.EMPTY) ++
        pushVector(vector) ++
        strings.stubs.templates.PUSH_ALL ++ strings.stubs.templates.NEWLINE ++
        saveDispatch() ++ strings.stubs.templates.NEWLINE ++
        strings.stubs.templates.CALL_EXCEPTION_DISPATCH ++ strings.stubs.templates.NEWLINE ++
        restoreDispatch() ++ strings.stubs.templates.NEWLINE ++
        strings.stubs.templates.POP_ALL ++ strings.stubs.templates.NEWLINE ++
        strings.stubs.templates.IRET_CLEANUP;
}

fn invocationStub() []const u8 {
    return strings.stubs.templates.PUSH_ZERO ++
        pushVector(vectors.INVOCATION_VECTOR) ++
        strings.stubs.templates.PUSH_ALL ++ strings.stubs.templates.NEWLINE ++
        saveDispatch() ++ strings.stubs.templates.NEWLINE ++
        strings.stubs.templates.CALL_INVOCATION_DISPATCH ++ strings.stubs.templates.NEWLINE ++
        restoreDispatch() ++ strings.stubs.templates.NEWLINE ++
        strings.stubs.templates.POP_ALL ++ strings.stubs.templates.NEWLINE ++
        strings.stubs.templates.IRET_CLEANUP;
}

pub fn irqStub(comptime irq: u8) []const u8 {
    return strings.stubs.templates.PUSH_ZERO ++
        pushVector(irq + constants.vectors.VECTOR_OFFSET) ++
        strings.stubs.templates.PUSH_ALL ++ strings.stubs.templates.NEWLINE ++
        saveDispatch() ++ strings.stubs.templates.NEWLINE ++
        strings.stubs.templates.CALL_IRQ_DISPATCH ++ strings.stubs.templates.NEWLINE ++
        restoreDispatch() ++ strings.stubs.templates.NEWLINE ++
        strings.stubs.templates.POP_ALL ++ strings.stubs.templates.NEWLINE ++
        strings.stubs.templates.IRET_CLEANUP;
}

pub fn makeExceptionHandler(comptime vector: u8, comptime has_error_code: bool) fn () callconv(.naked) void {
    return struct {
        fn handler() callconv(.naked) void {
            asm volatile (exceptionStub(vector, has_error_code));
        }
    }.handler;
}

pub fn makeInvocationHandler() fn () callconv(.naked) void {
    return struct {
        fn handler() callconv(.naked) void {
            asm volatile (invocationStub());
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
