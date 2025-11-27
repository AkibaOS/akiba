//! Interrupt Descriptor Table

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

var idt: [256]IDTEntry = [_]IDTEntry{.{
    .offset_low = 0,
    .selector = 0,
    .ist = 0,
    .type_attr = 0,
    .offset_mid = 0,
    .offset_high = 0,
    .reserved = 0,
}} ** 256;

comptime {
    asm (
        \\.global exception_handler_asm
        \\exception_handler_asm:
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
        \\  call exception_handler_inner
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
        \\.global keyboard_irq_handler_asm
        \\keyboard_irq_handler_asm:
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
        \\  call keyboard_interrupt_handler
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

extern fn exception_handler_asm() void;
extern fn keyboard_irq_handler_asm() void;
extern fn keyboard_interrupt_handler() void;

export fn exception_handler_inner() void {
    serial.print("\r\n!!! CPU EXCEPTION !!!\r\n");
    while (true) {
        asm volatile ("hlt");
    }
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

pub fn init() void {
    serial.print("Setting up IDT...\r\n");

    // Set up exception handlers (0-31)
    var i: u16 = 0;
    while (i < 32) : (i += 1) {
        set_handler(i, @intFromPtr(&exception_handler_asm));
    }

    // Set up keyboard interrupt (IRQ1 = INT 33)
    set_handler(33, @intFromPtr(&keyboard_irq_handler_asm));

    const idtr = IDTPointer{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (&idtr),
    );

    // Remap PIC (Programmable Interrupt Controller)
    remap_pic();

    // Unmask keyboard interrupt (IRQ1)
    unmask_irq(1);

    // Enable interrupts
    asm volatile ("sti");

    serial.print("IDT loaded, interrupts enabled\r\n");
}

fn set_handler(vector: u16, handler_addr: u64) void {
    idt[vector] = .{
        .offset_low = @truncate(handler_addr),
        .selector = 0x08,
        .ist = 0,
        .type_attr = 0x8E,
        .offset_mid = @truncate(handler_addr >> 16),
        .offset_high = @truncate(handler_addr >> 32),
        .reserved = 0,
    };
}

fn remap_pic() void {
    // Save masks
    const mask1 = inb(0x21);
    const mask2 = inb(0xA1);

    // Start initialization
    outb(0x20, 0x11);
    outb(0xA0, 0x11);

    // Remap IRQs 0-7 to INT 32-39, IRQs 8-15 to INT 40-47
    outb(0x21, 32);
    outb(0xA1, 40);

    // Setup cascade
    outb(0x21, 0x04);
    outb(0xA1, 0x02);

    // 8086 mode
    outb(0x21, 0x01);
    outb(0xA1, 0x01);

    // Restore masks
    outb(0x21, mask1);
    outb(0xA1, mask2);
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

fn unmask_irq(irq: u8) void {
    const port: u16 = if (irq < 8) 0x21 else 0xA1;
    const mask = inb(port) & ~(@as(u8, 1) << @truncate(irq % 8));
    outb(port, mask);
}
