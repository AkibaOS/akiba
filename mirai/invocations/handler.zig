//! Invocation Handler - Entry point for Persona programs calling kernel
//! Handles the AI Table (Akiba Invocation Table)

const serial = @import("../drivers/serial.zig");
const table = @import("table.zig");
const gdt = @import("../boot/gdt.zig");

pub const AI_EXIT = 0x01;

pub fn init() void {
    serial.print("\n=== Invocation Handler ===\n");
    serial.print("AI Table initialized\n");

    const syscall = @import("syscall.zig");
    syscall.init();
}

pub fn handle_invocation(context: *InvocationContext) void {
    const invocation_num = context.rax;

    switch (invocation_num) {
        AI_EXIT => table.invoke_exit(context),
        else => {
            serial.print("Unknown invocation: ");
            serial.print_hex(invocation_num);
            serial.print("\n");
            context.rax = @as(u64, @bitCast(@as(i64, -1)));
        },
    }
}

pub const InvocationContext = struct {
    rax: u64,
    rdi: u64,
    rsi: u64,
    rdx: u64,
    r10: u64,
    r8: u64,
    r9: u64,
    rbx: u64,
    rcx: u64,
    rbp: u64,
    rsp: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    rip: u64,
    rflags: u64,
    cs: u64,
    ss: u64,
};
