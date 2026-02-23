//! CPU exception handler

const kata_memory = @import("../kata/memory.zig");
const memory = @import("../asm/memory.zig");
const panic = @import("panic.zig");
const sensei = @import("../kata/sensei/sensei.zig");
const serial = @import("../drivers/serial/serial.zig");
const types = @import("types.zig");

const NAMES = [_][]const u8{
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
    const frame = @as(*types.ExceptionFrame, @ptrFromInt(frame_ptr));

    // Handle page faults - check for stack growth
    if (frame.int_num == 14) {
        const cr2 = memory.read_page_fault_address();
        const is_not_present = (frame.error_code & 1) == 0;

        // Check if fault is in user stack region (demand paging)
        if (sensei.get_current_kata()) |kata| {
            if (cr2 >= kata.user_stack_bottom and cr2 < kata.user_stack_top and is_not_present) {
                if (kata_memory.grow_stack(kata, cr2)) {
                    return;
                }
            }
        }
    }

    serial.print("\n!!! EXCEPTION: ");
    if (frame.int_num < NAMES.len) {
        serial.print(NAMES[frame.int_num]);
    } else {
        serial.print("Unknown");
    }
    serial.print(" !!!\n");

    serial.printf("Vector: {x}\n", .{frame.int_num});
    serial.printf("Error Code: {x}\n", .{frame.error_code});
    serial.printf("RIP: {x}\n", .{frame.rip});
    serial.printf("CS: {x}\n", .{frame.cs});
    serial.printf("RFLAGS: {x}\n", .{frame.rflags});
    serial.printf("RSP: {x}\n", .{frame.rsp});
    serial.printf("SS: {x}\n", .{frame.ss});

    if (frame.int_num == 14) {
        const cr2 = memory.read_page_fault_address();
        serial.printf("CR2 (fault addr): {x}\n", .{cr2});

        if (sensei.get_current_kata()) |kata| {
            serial.printf("Stack: bottom={x} committed={x} top={x}\n", .{ kata.user_stack_bottom, kata.user_stack_committed, kata.user_stack_top });
        }

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

        serial.printf("CR3 (page table): {x}\n", .{memory.read_page_table_base()});
    }

    serial.print("\nRegisters:\n");
    serial.printf("RAX: {x}  RBX: {x}\n", .{ frame.rax, frame.rbx });
    serial.printf("RCX: {x}  RDX: {x}\n", .{ frame.rcx, frame.rdx });
    serial.printf("RSI: {x}  RDI: {x}\n", .{ frame.rsi, frame.rdi });
    serial.printf("RBP: {x}\n", .{frame.rbp});
    serial.printf("R8:  {x}  R9:  {x}\n", .{ frame.r8, frame.r9 });
    serial.printf("R10: {x}  R11: {x}\n", .{ frame.r10, frame.r11 });
    serial.printf("R12: {x}  R13: {x}\n", .{ frame.r12, frame.r13 });
    serial.printf("R14: {x}  R15: {x}\n", .{ frame.r14, frame.r15 });

    if (frame.int_num < NAMES.len) {
        panic.collapse(NAMES[frame.int_num], null);
    } else {
        panic.collapse("Unknown Exception", null);
    }
}
