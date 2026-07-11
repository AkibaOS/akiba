//! PIC End-of-Interrupt

const ports = @import("constants/ports.zig");
const asm_io = @import("../../asm/io/io.zig");

pub fn send(irq: u4) void {
    if (irq >= 8) {
        asm_io.outb(ports.pic2_command, ports.eoi);
    }
    asm_io.outb(ports.pic1_command, ports.eoi);
}

pub fn send_master() void {
    asm_io.outb(ports.pic1_command, ports.eoi);
}

pub fn send_slave() void {
    asm_io.outb(ports.pic2_command, ports.eoi);
    asm_io.outb(ports.pic1_command, ports.eoi);
}
