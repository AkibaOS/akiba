//! PIC Initialization

const ports = @import("constants/ports.zig");
const asm_io = @import("../../asm/io/io.zig");

pub fn remap() void {
    const mask1 = asm_io.inb(ports.pic1_data);
    const mask2 = asm_io.inb(ports.pic2_data);

    asm_io.outb(ports.pic1_command, ports.icw1_init | ports.icw1_icw4);
    io_wait();
    asm_io.outb(ports.pic2_command, ports.icw1_init | ports.icw1_icw4);
    io_wait();

    asm_io.outb(ports.pic1_data, ports.vector_offset_master);
    io_wait();
    asm_io.outb(ports.pic2_data, ports.vector_offset_slave);
    io_wait();

    asm_io.outb(ports.pic1_data, 4);
    io_wait();
    asm_io.outb(ports.pic2_data, 2);
    io_wait();

    asm_io.outb(ports.pic1_data, ports.icw4_8086);
    io_wait();
    asm_io.outb(ports.pic2_data, ports.icw4_8086);
    io_wait();

    asm_io.outb(ports.pic1_data, mask1);
    asm_io.outb(ports.pic2_data, mask2);
}

pub fn disable() void {
    asm_io.outb(ports.pic1_data, 0xFF);
    asm_io.outb(ports.pic2_data, 0xFF);
}

fn io_wait() void {
    asm_io.outb(0x80, 0);
}
