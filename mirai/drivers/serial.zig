//! Serial port driver for debug output (COM1)

const PORT: u16 = 0x3F8;

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

pub fn init() void {
    outb(PORT + 1, 0x00);
    outb(PORT + 3, 0x80);
    outb(PORT + 0, 0x03);
    outb(PORT + 1, 0x00);
    outb(PORT + 3, 0x03);
    outb(PORT + 2, 0xC7);
    outb(PORT + 4, 0x0B);
}

fn is_transmit_empty() bool {
    return (inb(PORT + 5) & 0x20) != 0;
}

pub fn write(byte: u8) void {
    while (!is_transmit_empty()) {}
    outb(PORT, byte);
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
