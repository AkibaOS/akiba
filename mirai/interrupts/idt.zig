//! Interrupt Descriptor Table

const cpu = @import("../asm/cpu.zig");
const gdt_const = @import("../common/constants/gdt.zig");
const idt_const = @import("../common/constants/idt.zig");
const isr = @import("../asm/isr.zig");
const pic = @import("pic.zig");
const serial = @import("../drivers/serial/serial.zig");
const types = @import("types.zig");

comptime {
    _ = @import("../crimson/exception.zig");
    _ = @import("handlers.zig");
}

var table: [idt_const.NUM_ENTRIES]types.Entry align(16) = [_]types.Entry{.{
    .offset_low = 0,
    .selector = 0,
    .ist = 0,
    .type_attr = 0,
    .offset_mid = 0,
    .offset_high = 0,
    .reserved = 0,
}} ** idt_const.NUM_ENTRIES;

var pointer: types.Pointer = undefined;

pub fn init() void {
    serial.print("\n=== IDT ===\n");

    for (0..idt_const.NUM_EXCEPTIONS) |i| {
        const handler_addr = @intFromPtr(isr.get_exception_handler(@intCast(i)));
        // Use IST1 for double fault (8) and page fault (14)
        if (i == 8 or i == 14) {
            set_gate_with_ist(@intCast(i), handler_addr, gdt_const.KERNEL_CODE, idt_const.GATE_INTERRUPT, 1);
        } else {
            set_gate(@intCast(i), handler_addr, gdt_const.KERNEL_CODE, idt_const.GATE_INTERRUPT);
        }
    }

    set_gate(idt_const.VECTOR_TIMER, @intFromPtr(isr.get_irq_handler(0)), gdt_const.KERNEL_CODE, idt_const.GATE_INTERRUPT);
    set_gate(idt_const.VECTOR_KEYBOARD, @intFromPtr(isr.get_irq_handler(1)), gdt_const.KERNEL_CODE, idt_const.GATE_INTERRUPT);

    pointer = types.Pointer{
        .limit = @sizeOf(@TypeOf(table)) - 1,
        .base = @intFromPtr(&table),
    };

    cpu.load_interrupt_descriptor_table(@intFromPtr(&pointer));

    pic.remap();

    cpu.enable_interrupts();

    serial.print("IDT loaded\n");
}

fn set_gate(num: u8, handler: u64, selector: u16, type_attr: u8) void {
    set_gate_with_ist(num, handler, selector, type_attr, 0);
}

fn set_gate_with_ist(num: u8, handler: u64, selector: u16, type_attr: u8, ist: u8) void {
    table[num] = types.Entry{
        .offset_low = @truncate(handler & 0xFFFF),
        .selector = selector,
        .ist = ist,
        .type_attr = type_attr,
        .offset_mid = @truncate((handler >> 16) & 0xFFFF),
        .offset_high = @truncate(handler >> 32),
        .reserved = 0,
    };
}
