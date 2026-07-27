//! PIC End-of-Interrupt

const io = @import("asm").io;

const constants = @import("../constants/constants.zig");

const ports = constants.pic.ports;

pub fn send(irq: u4) void {
    if (irq >= ports.IRQS_PER_PIC) {
        io.port.writeByte(ports.PIC2_COMMAND, ports.EOI);
    }
    io.port.writeByte(ports.PIC1_COMMAND, ports.EOI);
}

pub fn sendMaster() void {
    io.port.writeByte(ports.PIC1_COMMAND, ports.EOI);
}

pub fn sendSlave() void {
    io.port.writeByte(ports.PIC2_COMMAND, ports.EOI);
    io.port.writeByte(ports.PIC1_COMMAND, ports.EOI);
}
