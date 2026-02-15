//! Interrupt Descriptor Table - IDT setup and IRQ routing

const cpu = @import("../asm/cpu.zig");
const io = @import("../asm/io.zig");
const isr = @import("../asm/isr.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial/serial.zig");

comptime {
    _ = @import("../crimson/exception.zig");
}

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

var idt_ptr: IDTPointer = undefined;

pub fn init() void {
    serial.print("\n=== Interrupt Descriptor Table ===\n");

    // Setup exception handlers (0-31)
    var i: u8 = 0;
    while (i < 32) : (i += 1) {
        const handler_addr = @intFromPtr(isr.get_exception_handler(i));
        set_gate(i, handler_addr, 0x08, 0x8E);
    }

    // Setup IRQ handlers
    // IRQ 0 = Timer (vector 32)
    set_gate(32, @intFromPtr(isr.get_irq_handler(0)), 0x08, 0x8E);
    // IRQ 1 = Keyboard (vector 33)
    set_gate(33, @intFromPtr(isr.get_irq_handler(1)), 0x08, 0x8E);

    // Setup IDT pointer
    idt_ptr = IDTPointer{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    // Load IDT
    cpu.load_interrupt_descriptor_table(@intFromPtr(&idt_ptr));

    // Remap PIC
    remap_pic();

    // Enable interrupts
    cpu.enable_interrupts();

    serial.print("IDT loaded, interrupts enabled\n");
}

fn set_gate(num: u8, handler: u64, selector: u16, type_attr: u8) void {
    idt[num] = IDTEntry{
        .offset_low = @truncate(handler & 0xFFFF),
        .selector = selector,
        .ist = 0,
        .type_attr = type_attr,
        .offset_mid = @truncate((handler >> 16) & 0xFFFF),
        .offset_high = @truncate(handler >> 32),
        .reserved = 0,
    };
}

fn remap_pic() void {
    // ICW1: Initialize + ICW4 needed
    io.out_byte(0x20, 0x11);
    io.out_byte(0xA0, 0x11);

    // ICW2: Vector offsets
    io.out_byte(0x21, 0x20); // Master PIC: IRQ 0-7 -> vectors 32-39
    io.out_byte(0xA1, 0x28); // Slave PIC: IRQ 8-15 -> vectors 40-47

    // ICW3: Cascade setup
    io.out_byte(0x21, 0x04); // Master: slave on IRQ2
    io.out_byte(0xA1, 0x02); // Slave: cascade identity

    // ICW4: 8086 mode
    io.out_byte(0x21, 0x01);
    io.out_byte(0xA1, 0x01);

    // Mask all interrupts except IRQ0 (timer) and IRQ1 (keyboard)
    io.out_byte(0x21, 0xFC); // 11111100 - enable IRQ0, IRQ1
    io.out_byte(0xA1, 0xFF); // Mask all slave IRQs
}

// Timer interrupt handler
export fn timer_handler() void {
    // Send EOI to PIC
    io.out_byte(0x20, 0x20);

    // Update scheduler
    sensei.on_tick();
}
