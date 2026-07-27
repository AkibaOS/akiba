//! PIC IRQ Masking

const io = @import("asm").io;

const constants = @import("../constants/constants.zig");

const ports = constants.pic.ports;

pub fn enableIRQ(irq: u4) void {
    if (irq < ports.IRQS_PER_PIC) {
        const mask = io.port.readByte(ports.PIC1_DATA);
        io.port.writeByte(ports.PIC1_DATA, mask & ~(@as(u8, 1) << @truncate(irq)));
    } else {
        const mask = io.port.readByte(ports.PIC2_DATA);
        io.port.writeByte(ports.PIC2_DATA, mask & ~(@as(u8, 1) << @truncate(irq - ports.IRQS_PER_PIC)));
    }
}

pub fn disableIRQ(irq: u4) void {
    if (irq < ports.IRQS_PER_PIC) {
        const mask = io.port.readByte(ports.PIC1_DATA);
        io.port.writeByte(ports.PIC1_DATA, mask | (@as(u8, 1) << @truncate(irq)));
    } else {
        const mask = io.port.readByte(ports.PIC2_DATA);
        io.port.writeByte(ports.PIC2_DATA, mask | (@as(u8, 1) << @truncate(irq - ports.IRQS_PER_PIC)));
    }
}

pub fn maskAll() void {
    io.port.writeByte(ports.PIC1_DATA, ports.MASK_ALL);
    io.port.writeByte(ports.PIC2_DATA, ports.MASK_ALL);
}

pub fn unmaskAll() void {
    io.port.writeByte(ports.PIC1_DATA, ports.MASK_NONE);
    io.port.writeByte(ports.PIC2_DATA, ports.MASK_NONE);
}

pub fn getMask() u16 {
    const low = io.port.readByte(ports.PIC1_DATA);
    const high = io.port.readByte(ports.PIC2_DATA);
    return @as(u16, high) << @bitSizeOf(u8) | low;
}
