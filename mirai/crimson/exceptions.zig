//! Exception Handler - Crimson panic for CPU exceptions

const memory = @import("../asm/memory.zig");
const panic = @import("panic.zig");
const serial = @import("../drivers/serial/serial.zig");

// ISR stubs are defined in mirai/asm/isr.zig
// The comptime assembly block has been moved there

const ExceptionFrame = packed struct {
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rbp: u64,
    rdi: u64,
    rsi: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,
    int_num: u64,
    error_code: u64,
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};

const EXCEPTION_NAMES = [_][]const u8{
    "Division By Zero",
    "Debug",
    "Non-Maskable Interrupt",
    "Breakpoint",
    "Overflow",
    "Bound Range Exceeded",
    "Invalid Opcode",
    "Device Not Available",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Invalid TSS",
    "Segment Not Present",
    "Stack-Segment Fault",
    "General Protection Fault",
    "Page Fault",
    "Reserved",
    "x87 Floating-Point Exception",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating-Point Exception",
    "Virtualization Exception",
    "Control Protection Exception",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Hypervisor Injection Exception",
    "VMM Communication Exception",
    "Security Exception",
    "Reserved",
};

export fn exception_handler(frame_ptr: u64) void {
    const frame = @as(*ExceptionFrame, @ptrFromInt(frame_ptr));

    serial.print("\n!!! EXCEPTION: ");
    if (frame.int_num < EXCEPTION_NAMES.len) {
        serial.print(EXCEPTION_NAMES[frame.int_num]);
    } else {
        serial.print("Unknown");
    }
    serial.print(" !!!\n");

    serial.print("Vector: ");
    serial.print_hex(frame.int_num);
    serial.print("\n");

    serial.print("Error Code: ");
    serial.print_hex(frame.error_code);
    serial.print("\n");

    serial.print("RIP: ");
    serial.print_hex(frame.rip);
    serial.print("\n");

    serial.print("CS: ");
    serial.print_hex(frame.cs);
    serial.print("\n");

    serial.print("RFLAGS: ");
    serial.print_hex(frame.rflags);
    serial.print("\n");

    serial.print("RSP: ");
    serial.print_hex(frame.rsp);
    serial.print("\n");

    serial.print("SS: ");
    serial.print_hex(frame.ss);
    serial.print("\n");

    // Page fault specific info
    if (frame.int_num == 14) {
        const cr2 = memory.read_page_fault_address();
        serial.print("CR2 (fault addr): ");
        serial.print_hex(cr2);
        serial.print("\n");

        serial.print("Fault type: ");
        if ((frame.error_code & 1) == 0) {
            serial.print("Page not present");
        } else {
            serial.print("Protection violation");
        }
        if ((frame.error_code & 2) != 0) {
            serial.print(", Write");
        } else {
            serial.print(", Read");
        }
        if ((frame.error_code & 4) != 0) {
            serial.print(", User mode");
        } else {
            serial.print(", Kernel mode");
        }
        serial.print("\n");

        const cr3 = memory.read_page_table_base();
        serial.print("CR3 (page table): ");
        serial.print_hex(cr3);
        serial.print("\n");
    }

    serial.print("\nRegisters:\n");
    serial.print("RAX: ");
    serial.print_hex(frame.rax);
    serial.print("  RBX: ");
    serial.print_hex(frame.rbx);
    serial.print("\n");
    serial.print("RCX: ");
    serial.print_hex(frame.rcx);
    serial.print("  RDX: ");
    serial.print_hex(frame.rdx);
    serial.print("\n");
    serial.print("RSI: ");
    serial.print_hex(frame.rsi);
    serial.print("  RDI: ");
    serial.print_hex(frame.rdi);
    serial.print("\n");
    serial.print("RBP: ");
    serial.print_hex(frame.rbp);
    serial.print("\n");
    serial.print("R8:  ");
    serial.print_hex(frame.r8);
    serial.print("  R9:  ");
    serial.print_hex(frame.r9);
    serial.print("\n");
    serial.print("R10: ");
    serial.print_hex(frame.r10);
    serial.print("  R11: ");
    serial.print_hex(frame.r11);
    serial.print("\n");
    serial.print("R12: ");
    serial.print_hex(frame.r12);
    serial.print("  R13: ");
    serial.print_hex(frame.r13);
    serial.print("\n");
    serial.print("R14: ");
    serial.print_hex(frame.r14);
    serial.print("  R15: ");
    serial.print_hex(frame.r15);
    serial.print("\n");

    // Trigger Crimson panic
    // Note: We pass null for context since ExceptionFrame layout differs from panic.Context
    // All register info has already been printed to serial above
    if (frame.int_num < EXCEPTION_NAMES.len) {
        panic.collapse(EXCEPTION_NAMES[frame.int_num], null);
    } else {
        panic.collapse("Unknown Exception", null);
    }
}
