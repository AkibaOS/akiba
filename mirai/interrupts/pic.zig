//! PIC remapping

const io = @import("../asm/io.zig");
const pic = @import("../common/constants/pic.zig");

pub fn remap() void {
    io.out_byte(pic.MASTER_CMD, pic.ICW1_INIT);
    io.out_byte(pic.SLAVE_CMD, pic.ICW1_INIT);

    io.out_byte(pic.MASTER_DATA, pic.MASTER_OFFSET);
    io.out_byte(pic.SLAVE_DATA, pic.SLAVE_OFFSET);

    io.out_byte(pic.MASTER_DATA, pic.MASTER_CASCADE);
    io.out_byte(pic.SLAVE_DATA, pic.SLAVE_CASCADE);

    io.out_byte(pic.MASTER_DATA, pic.ICW4_8086);
    io.out_byte(pic.SLAVE_DATA, pic.ICW4_8086);

    io.out_byte(pic.MASTER_DATA, pic.MASK_TIMER_KEYBOARD);
    io.out_byte(pic.SLAVE_DATA, pic.MASK_ALL);
}

pub fn send_eoi_master() void {
    io.out_byte(pic.MASTER_CMD, pic.EOI);
}

pub fn send_eoi_slave() void {
    io.out_byte(pic.SLAVE_CMD, pic.EOI);
    io.out_byte(pic.MASTER_CMD, pic.EOI);
}
