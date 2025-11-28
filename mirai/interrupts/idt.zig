//! Interrupt Descriptor Table and exception handlers

const serial = @import("../drivers/serial.zig");

const IDTEntry = packed struct {
    offset_low: u16,
    selector: u16,
    ist: u8,
    type_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    reserved: u32,
};

const IDTPointer = packed struct {
    limit: u16,
    base: u64,
};

const InterruptFrame = packed struct {
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

var idt: [256]IDTEntry align(16) = [_]IDTEntry{.{
    .offset_low = 0,
    .selector = 0,
    .ist = 0,
    .type_attr = 0,
    .offset_mid = 0,
    .offset_high = 0,
    .reserved = 0,
}} ** 256;

var tick_count: u64 = 0;

// Assembly interrupt stubs
comptime {
    // Generate exception handlers (0-31)
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        if (i == 8 or (i >= 10 and i <= 14) or i == 17 or i == 21) {
            // Exceptions with error code
            asm (std.fmt.comptimePrint(
                    \\.global isr{d}
                    \\isr{d}:
                    \\  push ${d}
                    \\  jmp common_exception_handler
                , .{ i, i, i }));
        } else {
            // Exceptions without error code
            asm (std.fmt.comptimePrint(
                    \\.global isr{d}
                    \\isr{d}:
                    \\  push $0
                    \\  push ${d}
                    \\  jmp common_exception_handler
                , .{ i, i, i }));
        }
    }

    // Common exception handler
    asm (
        \\common_exception_handler:
        \\  push %rax
        \\  push %rbx
        \\  push %rcx
        \\  push %rdx
        \\  push %rsi
        \\  push %rdi
        \\  push %rbp
        \\  push %r8
        \\  push %r9
        \\  push %r10
        \\  push %r11
        \\  push %r12
        \\  push %r13
        \\  push %r14
        \\  push %r15
        \\  mov %rsp, %rdi
        \\  call exception_handler
        \\  pop %r15
        \\  pop %r14
        \\  pop %r13
        \\  pop %r12
        \\  pop %r11
        \\  pop %r10
        \\  pop %r9
        \\  pop %r8
        \\  pop %rbp
        \\  pop %rdi
        \\  pop %rsi
        \\  pop %rdx
        \\  pop %rcx
        \\  pop %rbx
        \\  pop %rax
        \\  add $16, %rsp
        \\  iretq
    );

    // IRQ handlers
    asm (
        \\.global irq0_handler
        \\irq0_handler:
        \\  push %rax
        \\  push %rbx
        \\  push %rcx
        \\  push %rdx
        \\  push %rsi
        \\  push %rdi
        \\  push %rbp
        \\  push %r8
        \\  push %r9
        \\  push %r10
        \\  push %r11
        \\  push %r12
        \\  push %r13
        \\  push %r14
        \\  push %r15
        \\  call timer_handler
        \\  pop %r15
        \\  pop %r14
        \\  pop %r13
        \\  pop %r12
        \\  pop %r11
        \\  pop %r10
        \\  pop %r9
        \\  pop %r8
        \\  pop %rbp
        \\  pop %rdi
        \\  pop %rsi
        \\  pop %rdx
        \\  pop %rcx
        \\  pop %rbx
        \\  pop %rax
        \\  iretq
        \\
        \\.global irq1_handler
        \\irq1_handler:
        \\  push %rax
        \\  push %rbx
        \\  push %rcx
        \\  push %rdx
        \\  push %rsi
        \\  push %rdi
        \\  push %rbp
        \\  push %r8
        \\  push %r9
        \\  push %r10
        \\  push %r11
        \\  push %r12
        \\  push %r13
        \\  push %r14
        \\  push %r15
        \\  call keyboard_handler
        \\  pop %r15
        \\  pop %r14
        \\  pop %r13
        \\  pop %r12
        \\  pop %r11
        \\  pop %r10
        \\  pop %r9
        \\  pop %r8
        \\  pop %rbp
        \\  pop %rdi
        \\  pop %rsi
        \\  pop %rdx
        \\  pop %rcx
        \\  pop %rbx
        \\  pop %rax
        \\  iretq
    );
}

const std = @import("std");

// Declare ISR symbols
extern fn isr0() void;
extern fn isr1() void;
extern fn isr2() void;
extern fn isr3() void;
extern fn isr4() void;
extern fn isr5() void;
extern fn isr6() void;
extern fn isr7() void;
extern fn isr8() void;
extern fn isr9() void;
extern fn isr10() void;
extern fn isr11() void;
extern fn isr12() void;
extern fn isr13() void;
extern fn isr14() void;
extern fn isr15() void;
extern fn isr16() void;
extern fn isr17() void;
extern fn isr18() void;
extern fn isr19() void;
extern fn isr20() void;
extern fn isr21() void;
extern fn isr22() void;
extern fn isr23() void;
extern fn isr24() void;
extern fn isr25() void;
extern fn isr26() void;
extern fn isr27() void;
extern fn isr28() void;
extern fn isr29() void;
extern fn isr30() void;
extern fn isr31() void;

extern fn irq0_handler() void;
extern fn irq1_handler() void;
extern fn keyboard_handler() void;

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

export fn exception_handler(frame: *InterruptFrame) void {
    serial.print("\n\n");
    serial.print("╔════════════════════════════════════╗\n");
    serial.print("║     CPU EXCEPTION OCCURRED         ║\n");
    serial.print("╚════════════════════════════════════╝\n\n");

    const int_num = frame.int_num;

    if (int_num < 32) {
        serial.print("Exception: ");
        serial.print(EXCEPTION_NAMES[int_num]);
        serial.print("\n");
    } else {
        serial.print("Exception: ");
        serial.print_hex(int_num);
        serial.print("\n");
    }

    serial.print("Error Code: ");
    serial.print_hex(frame.error_code);
    serial.print("\n");

    serial.print("RIP: ");
    serial.print_hex(frame.rip);
    serial.print("\n");

    serial.print("CS:  ");
    serial.print_hex(frame.cs);
    serial.print("\n");

    serial.print("RFLAGS: ");
    serial.print_hex(frame.rflags);
    serial.print("\n");

    serial.print("RSP: ");
    serial.print_hex(frame.rsp);
    serial.print("\n");

    serial.print("SS:  ");
    serial.print_hex(frame.ss);
    serial.print("\n\n");

    serial.print("Register Dump:\n");
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
    serial.print("\n\n");

    // Special handling for page fault
    if (int_num == 14) {
        const cr2 = asm volatile ("mov %%cr2, %[result]"
            : [result] "=r" (-> u64),
        );
        serial.print("Page Fault Address (CR2): ");
        serial.print_hex(cr2);
        serial.print("\n");

        serial.print("Fault Type: ");
        if ((frame.error_code & 1) != 0) {
            serial.print("Page protection violation");
        } else {
            serial.print("Non-present page");
        }
        if ((frame.error_code & 2) != 0) {
            serial.print(" (write)");
        } else {
            serial.print(" (read)");
        }
        if ((frame.error_code & 4) != 0) {
            serial.print(" [user mode]");
        } else {
            serial.print(" [kernel mode]");
        }
        serial.print("\n");
    }

    serial.print("\nSystem Halted.\n");

    while (true) {
        asm volatile ("cli; hlt");
    }
}

export fn timer_handler() void {
    tick_count += 1;

    // Send EOI to PIC
    outb(0x20, 0x20);
}

pub fn get_ticks() u64 {
    return tick_count;
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

pub fn init() void {
    serial.print("\n=== Interrupt Descriptor Table ===\n");

    // Set up exception handlers (0-31)
    const isrs = [_]u64{
        @intFromPtr(&isr0),  @intFromPtr(&isr1),  @intFromPtr(&isr2),  @intFromPtr(&isr3),
        @intFromPtr(&isr4),  @intFromPtr(&isr5),  @intFromPtr(&isr6),  @intFromPtr(&isr7),
        @intFromPtr(&isr8),  @intFromPtr(&isr9),  @intFromPtr(&isr10), @intFromPtr(&isr11),
        @intFromPtr(&isr12), @intFromPtr(&isr13), @intFromPtr(&isr14), @intFromPtr(&isr15),
        @intFromPtr(&isr16), @intFromPtr(&isr17), @intFromPtr(&isr18), @intFromPtr(&isr19),
        @intFromPtr(&isr20), @intFromPtr(&isr21), @intFromPtr(&isr22), @intFromPtr(&isr23),
        @intFromPtr(&isr24), @intFromPtr(&isr25), @intFromPtr(&isr26), @intFromPtr(&isr27),
        @intFromPtr(&isr28), @intFromPtr(&isr29), @intFromPtr(&isr30), @intFromPtr(&isr31),
    };

    for (isrs, 0..) |handler_addr, i| {
        set_handler(@intCast(i), handler_addr, 0x8E);
    }

    // Set up IRQ handlers (32-47)
    set_handler(32, @intFromPtr(&irq0_handler), 0x8E); // Timer
    set_handler(33, @intFromPtr(&irq1_handler), 0x8E); // Keyboard

    // Load IDT
    const idtr = IDTPointer{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (&idtr),
    );

    // Remap PIC
    remap_pic();

    // Unmask timer (IRQ0) and keyboard (IRQ1)
    unmask_irq(0);
    unmask_irq(1);

    // Enable interrupts
    asm volatile ("sti");

    serial.print("IDT loaded, interrupts enabled\n");
}

fn set_handler(vector: u16, handler_addr: u64, flags: u8) void {
    idt[vector] = .{
        .offset_low = @truncate(handler_addr),
        .selector = 0x08, // Kernel code segment
        .ist = 0,
        .type_attr = flags,
        .offset_mid = @truncate(handler_addr >> 16),
        .offset_high = @truncate(handler_addr >> 32),
        .reserved = 0,
    };
}

fn remap_pic() void {
    const mask1 = inb(0x21);
    const mask2 = inb(0xA1);

    outb(0x20, 0x11);
    outb(0xA0, 0x11);

    outb(0x21, 32);
    outb(0xA1, 40);

    outb(0x21, 0x04);
    outb(0xA1, 0x02);

    outb(0x21, 0x01);
    outb(0xA1, 0x01);

    outb(0x21, mask1);
    outb(0xA1, mask2);
}

fn unmask_irq(irq: u8) void {
    const port: u16 = if (irq < 8) 0x21 else 0xA1;
    const mask = inb(port) & ~(@as(u8, 1) << @truncate(irq % 8));
    outb(port, mask);
}
