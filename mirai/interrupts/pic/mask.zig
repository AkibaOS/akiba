//! PIC IRQ Masking

const ports = @import("constants/ports.zig");
const asm_io = @import("../../asm/io/io.zig");

pub fn enable_irq(irq: u4) void {
    if (irq < 8) {
        const mask = asm_io.inb(ports.pic1_data);
        asm_io.outb(ports.pic1_data, mask & ~(@as(u8, 1) << @truncate(irq)));
    } else {
        const mask = asm_io.inb(ports.pic2_data);
        asm_io.outb(ports.pic2_data, mask & ~(@as(u8, 1) << @truncate(irq - 8)));
    }
}

pub fn disable_irq(irq: u4) void {
    if (irq < 8) {
        const mask = asm_io.inb(ports.pic1_data);
        asm_io.outb(ports.pic1_data, mask | (@as(u8, 1) << @truncate(irq)));
    } else {
        const mask = asm_io.inb(ports.pic2_data);
        asm_io.outb(ports.pic2_data, mask | (@as(u8, 1) << @truncate(irq - 8)));
    }
}

pub fn mask_all() void {
    asm_io.outb(ports.pic1_data, 0xFF);
    asm_io.outb(ports.pic2_data, 0xFF);
}

pub fn unmask_all() void {
    asm_io.outb(ports.pic1_data, 0x00);
    asm_io.outb(ports.pic2_data, 0x00);
}

pub fn get_mask() u16 {
    const low = asm_io.inb(ports.pic1_data);
    const high = asm_io.inb(ports.pic2_data);
    return @as(u16, high) << 8 | low;
}
