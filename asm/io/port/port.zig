//! Port I/O Operations

const constants = @import("asm").io.constants.port;
const strings = @import("asm").io.strings.port;

pub fn readByte(port: u16) u8 {
    var result: u8 = undefined;
    asm volatile (strings.READ_BYTE
        : [result] "={al}" (result),
        : [port] "N{dx}" (port),
    );
    return result;
}

pub fn writeByte(port: u16, value: u8) void {
    asm volatile (strings.WRITE_BYTE
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

pub fn readWord(port: u16) u16 {
    var result: u16 = undefined;
    asm volatile (strings.READ_WORD
        : [result] "={ax}" (result),
        : [port] "N{dx}" (port),
    );
    return result;
}

pub fn writeWord(port: u16, value: u16) void {
    asm volatile (strings.WRITE_WORD
        :
        : [value] "{ax}" (value),
          [port] "N{dx}" (port),
    );
}

pub fn readLong(port: u16) u32 {
    var result: u32 = undefined;
    asm volatile (strings.READ_LONG
        : [result] "={eax}" (result),
        : [port] "N{dx}" (port),
    );
    return result;
}

pub fn writeLong(port: u16, value: u32) void {
    asm volatile (strings.WRITE_LONG
        :
        : [value] "{eax}" (value),
          [port] "N{dx}" (port),
    );
}

pub fn ioWait() void {
    writeByte(constants.DELAY_PORT, 0);
}
