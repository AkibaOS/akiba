//! Port I/O Operations

const constants = @import("../constants/constants.zig");

pub fn readByte(port: u16) u8 {
    var result: u8 = undefined;
    asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (result),
        : [port] "N{dx}" (port),
    );
    return result;
}

pub fn writeByte(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

pub fn readWord(port: u16) u16 {
    var result: u16 = undefined;
    asm volatile ("inw %[port], %[result]"
        : [result] "={ax}" (result),
        : [port] "N{dx}" (port),
    );
    return result;
}

pub fn writeWord(port: u16, value: u16) void {
    asm volatile ("outw %[value], %[port]"
        :
        : [value] "{ax}" (value),
          [port] "N{dx}" (port),
    );
}

pub fn readLong(port: u16) u32 {
    var result: u32 = undefined;
    asm volatile ("inl %[port], %[result]"
        : [result] "={eax}" (result),
        : [port] "N{dx}" (port),
    );
    return result;
}

pub fn writeLong(port: u16, value: u32) void {
    asm volatile ("outl %[value], %[port]"
        :
        : [value] "{eax}" (value),
          [port] "N{dx}" (port),
    );
}

pub fn ioWait() void {
    writeByte(constants.DELAY_PORT, 0);
}
