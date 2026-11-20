//! Independently Encoded ELF64 Image Bytes

const std = @import("std");

const inputs = @import("tests").fixtures.constants.elf.layout;

pub fn create() [inputs.DATA_BYTES]u8 {
    var bytes = [_]u8{0} ** inputs.DATA_BYTES;
    @memcpy(bytes[0..7], &[_]u8{ 0x7f, 'E', 'L', 'F', 2, 1, 1 });
    write16(&bytes, 16, 2);
    write16(&bytes, 18, 62);
    write32(&bytes, 20, 1);
    write64(&bytes, 24, inputs.CODE_ADDRESS + 1);
    write64(&bytes, 32, inputs.HEADER_BYTES);
    write16(&bytes, 52, inputs.HEADER_BYTES);
    write16(&bytes, 54, inputs.PROGRAM_BYTES);
    write16(&bytes, 56, inputs.PROGRAM_COUNT);
    for (0..inputs.PROGRAM_COUNT) |index| {
        const start = program(index);
        write32(&bytes, start, 1);
        write32(&bytes, start + 4, if (index == 0) 5 else if (index == 1) 4 else 6);
        write64(&bytes, start + 8, (index + 1) * inputs.PAGE_BYTES);
        write64(&bytes, start + 16, inputs.CODE_ADDRESS + index * inputs.PAGE_BYTES);
        write64(&bytes, start + 24, std.math.maxInt(u64));
        write64(&bytes, start + 32, if (index == 2) inputs.PAGE_BYTES + 1 else 32);
        write64(&bytes, start + 40, if (index == 2) 2 * inputs.PAGE_BYTES else inputs.PAGE_BYTES);
        write64(&bytes, start + 48, inputs.PAGE_BYTES);
    }
    @memset(bytes[inputs.PAGE_BYTES..][0..32], 0x90);
    @memset(bytes[2 * inputs.PAGE_BYTES ..][0..32], 0x5a);
    @memset(bytes[3 * inputs.PAGE_BYTES ..][0 .. inputs.PAGE_BYTES + 1], 0x3c);
    return bytes;
}

pub fn program(index: usize) usize {
    return inputs.HEADER_BYTES + index * inputs.PROGRAM_BYTES;
}

pub fn share(bytes: []u8, writable: bool) void {
    write64(bytes, program(0) + 40, 32);
    write32(bytes, program(1) + 4, if (writable) 6 else 4);
    write64(bytes, program(1) + 8, inputs.PAGE_BYTES + 0x100);
    write64(bytes, program(1) + 16, inputs.CODE_ADDRESS + 0x100);
    write64(bytes, program(1) + 40, 32);
    @memset(bytes[inputs.PAGE_BYTES + 0x100 ..][0..32], 0x5a);
}

pub fn write16(bytes: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, bytes[offset..][0..2], value, .little);
}

pub fn write32(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
}

pub fn write64(bytes: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, bytes[offset..][0..8], value, .little);
}
