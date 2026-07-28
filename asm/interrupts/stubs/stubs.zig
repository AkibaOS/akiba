//! Interrupt Handler Stub Builders

const std = @import("std");

const constants = @import("asm").interrupts.constants;
const strings = @import("asm").interrupts.strings;

pub fn pushVector(comptime vector: u8) []const u8 {
    return comptime std.fmt.comptimePrint(strings.stubs.PUSH_VECTOR_FORMAT, .{vector});
}

pub fn exceptionStub(comptime vector: u8, comptime has_error_code: bool) []const u8 {
    return (if (!has_error_code) strings.stubs.PUSH_ZERO else "") ++
        pushVector(vector) ++
        strings.stubs.PUSH_ALL ++ "\n" ++
        strings.stubs.CALL_EXCEPTION_DISPATCH ++ "\n" ++
        strings.stubs.POP_ALL ++ "\n" ++
        strings.stubs.IRET_CLEANUP;
}

pub fn irqStub(comptime irq: u8) []const u8 {
    return strings.stubs.PUSH_ZERO ++
        pushVector(irq + constants.VECTOR_OFFSET) ++
        strings.stubs.PUSH_ALL ++ "\n" ++
        strings.stubs.CALL_IRQ_DISPATCH ++ "\n" ++
        strings.stubs.POP_ALL ++ "\n" ++
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
