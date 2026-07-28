//! PIC Initialization

const io = @import("asm").io;

const constants = @import("mirai").interrupts.constants;

const ports = constants.pic.ports;

pub fn remap() void {
    const mask1 = io.port.readByte(ports.PIC1_DATA);
    const mask2 = io.port.readByte(ports.PIC2_DATA);

    io.port.writeByte(ports.PIC1_COMMAND, ports.ICW1_INIT | ports.ICW1_ICW4);
    io.port.ioWait();
    io.port.writeByte(ports.PIC2_COMMAND, ports.ICW1_INIT | ports.ICW1_ICW4);
    io.port.ioWait();

    io.port.writeByte(ports.PIC1_DATA, ports.VECTOR_OFFSET_MASTER);
    io.port.ioWait();
    io.port.writeByte(ports.PIC2_DATA, ports.VECTOR_OFFSET_SLAVE);
    io.port.ioWait();

    io.port.writeByte(ports.PIC1_DATA, ports.ICW3_MASTER_SLAVE_ON_IRQ2);
    io.port.ioWait();
    io.port.writeByte(ports.PIC2_DATA, ports.ICW3_SLAVE_CASCADE_IDENTITY);
    io.port.ioWait();

    io.port.writeByte(ports.PIC1_DATA, ports.ICW4_8086);
    io.port.ioWait();
    io.port.writeByte(ports.PIC2_DATA, ports.ICW4_8086);
    io.port.ioWait();

    io.port.writeByte(ports.PIC1_DATA, mask1);
    io.port.writeByte(ports.PIC2_DATA, mask2);
}

pub fn disable() void {
    io.port.writeByte(ports.PIC1_DATA, ports.MASK_ALL);
    io.port.writeByte(ports.PIC2_DATA, ports.MASK_ALL);
}
