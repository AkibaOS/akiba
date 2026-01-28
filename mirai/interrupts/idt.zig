//! Interrupt Descriptor Table - IDT setup and IRQ routing

const cpu = @import("../asm/cpu.zig");
const exceptions = @import("../crimson/exceptions.zig");
const io = @import("../asm/io.zig");
const sensei = @import("../kata/sensei.zig");
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

// Assembly IRQ handlers
comptime {
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

extern fn irq0_handler() void;
extern fn irq1_handler() void;
extern fn keyboard_handler() void;

export fn timer_handler() void {
    tick_count += 1;

    // Send EOI to PIC FIRST, before on_tick()
    // This is important because on_tick() might call schedule() which
    // calls shift_to_kata() which does iretq and never returns here.
    // Without early EOI, no more timer interrupts would fire.
    io.write_port_byte(0x20, 0x20);

    // Let Sensei schedule Kata on each tick
    sensei.on_tick();
}

pub fn get_ticks() u64 {
    return tick_count;
}

pub fn init() void {
    serial.print("\n=== Interrupt Descriptor Table ===\n");

    // Set up exception handlers (0-31) from Crimson
    const exception_handlers = exceptions.get_isr_handlers();
    for (exception_handlers, 0..) |handler_addr, i| {
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

    cpu.load_interrupt_descriptor_table(@intFromPtr(&idtr));

    // Remap PIC
    remap_pic();

    // Unmask timer (IRQ0) and keyboard (IRQ1)
    unmask_irq(0);
    unmask_irq(1);

    // Enable interrupts
    cpu.enable_interrupts();

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
    const mask1 = io.read_port_byte(0x21);
    const mask2 = io.read_port_byte(0xA1);

    io.write_port_byte(0x20, 0x11);
    io.write_port_byte(0xA0, 0x11);

    io.write_port_byte(0x21, 32);
    io.write_port_byte(0xA1, 40);

    io.write_port_byte(0x21, 0x04);
    io.write_port_byte(0xA1, 0x02);

    io.write_port_byte(0x21, 0x01);
    io.write_port_byte(0xA1, 0x01);

    io.write_port_byte(0x21, mask1);
    io.write_port_byte(0xA1, mask2);
}

fn unmask_irq(irq: u8) void {
    const port: u16 = if (irq < 8) 0x21 else 0xA1;
    const mask = io.read_port_byte(port) & ~(@as(u8, 1) << @truncate(irq % 8));
    io.write_port_byte(port, mask);
}
