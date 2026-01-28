//! Serial port driver for debug output (COM1)

const io = @import("../asm/io.zig");

const PORT: u16 = 0x3F8;

pub fn init() void {
    io.write_port_byte(PORT + 1, 0x00);
    io.write_port_byte(PORT + 3, 0x80);
    io.write_port_byte(PORT + 0, 0x03);
    io.write_port_byte(PORT + 1, 0x00);
    io.write_port_byte(PORT + 3, 0x03);
    io.write_port_byte(PORT + 2, 0xC7);
    io.write_port_byte(PORT + 4, 0x0B);
}

fn is_transmit_empty() bool {
    return (io.read_port_byte(PORT + 5) & 0x20) != 0;
}

pub fn write(byte: u8) void {
    while (!is_transmit_empty()) {}
    io.write_port_byte(PORT, byte);
}

pub fn print(str: []const u8) void {
    for (str) |c| {
        write(c);
    }
}

pub fn print_hex(value: u64) void {
    const hex_chars = "0123456789ABCDEF";
    var i: u6 = 60;
    while (true) : (i -%= 4) {
        const nibble = @as(u8, @truncate((value >> i) & 0xF));
        write(hex_chars[nibble]);
        if (i == 0) break;
    }
}
