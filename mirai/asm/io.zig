//! I/O Port Operations
//! Hardware communication through port-mapped I/O

/// Write 8-bit value to I/O port
pub inline fn write_port_byte(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

/// Read 8-bit value from I/O port
pub inline fn read_port_byte(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}

/// Write 16-bit value to I/O port
pub inline fn write_port_word(port: u16, value: u16) void {
    asm volatile ("outw %[value], %[port]"
        :
        : [value] "{ax}" (value),
          [port] "N{dx}" (port),
    );
}

/// Read 16-bit value from I/O port
pub inline fn read_port_word(port: u16) u16 {
    return asm volatile ("inw %[port], %[result]"
        : [result] "={ax}" (-> u16),
        : [port] "N{dx}" (port),
    );
}

/// Write 32-bit value to I/O port
pub inline fn write_port_long(port: u16, value: u32) void {
    asm volatile ("outl %[value], %[port]"
        :
        : [value] "{eax}" (value),
          [port] "N{dx}" (port),
    );
}

/// Read 32-bit value from I/O port
pub inline fn read_port_long(port: u16) u32 {
    return asm volatile ("inl %[port], %[result]"
        : [result] "={eax}" (-> u32),
        : [port] "N{dx}" (port),
    );
}
