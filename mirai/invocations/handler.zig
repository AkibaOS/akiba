//! Invocation Handler - Entry point for Persona programs calling kernel
//! Handles the AI Table (Akiba Invocation Table)

const gdt = @import("../boot/gdt.zig");
const serial = @import("../drivers/serial.zig");
const syscall = @import("syscall.zig");
const table = @import("table.zig");

// Invocation numbers (AI Table)
pub const AI_EXIT = 0x01;

pub fn init() void {
    serial.print("\n=== Invocation Handler ===\n");
    serial.print("AI Table initialized\n");

    // Initialize SYSCALL/SYSRET mechanism
    syscall.init();
}

// Called from interrupt handler when Layer 3 triggers INT 0x80
pub fn handle_invocation(context: *InvocationContext) void {
    const invocation_num = context.rax;

    // Debug output
    serial.print("Invocation: ");
    serial.print_hex(invocation_num);
    serial.print("\n");

    // Dispatch to AI Table
    switch (invocation_num) {
        AI_EXIT => table.invoke_exit(context),
        else => {
            serial.print("Unknown invocation: ");
            serial.print_hex(invocation_num);
            serial.print("\n");
            context.rax = @as(u64, @bitCast(@as(i64, -1))); // Return error
        },
    }
}

// Invocation context (registers passed from Layer 3)
pub const InvocationContext = struct {
    // Invocation number in RAX
    rax: u64,

    // Arguments in RDI, RSI, RDX, R10, R8, R9
    rdi: u64,
    rsi: u64,
    rdx: u64,
    r10: u64,
    r8: u64,
    r9: u64,

    // Preserved registers
    rbx: u64,
    rcx: u64,
    rbp: u64,
    rsp: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,

    // Return context
    rip: u64,
    rflags: u64,
    cs: u64,
    ss: u64,
};
