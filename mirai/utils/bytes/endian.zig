//! Byte order conversion utilities

const int = @import("../types/int.zig");

pub inline fn read_u16_le(bytes: []const u8) u16 {
    return int.u16_of(bytes[0]) |
        (int.u16_of(bytes[1]) << 8);
}

pub inline fn read_u32_le(bytes: []const u8) u32 {
    return int.u32_of(bytes[0]) |
        (int.u32_of(bytes[1]) << 8) |
        (int.u32_of(bytes[2]) << 16) |
        (int.u32_of(bytes[3]) << 24);
}

pub inline fn read_u64_le(bytes: []const u8) u64 {
    return int.u64_of(bytes[0]) |
        (int.u64_of(bytes[1]) << 8) |
        (int.u64_of(bytes[2]) << 16) |
        (int.u64_of(bytes[3]) << 24) |
        (int.u64_of(bytes[4]) << 32) |
        (int.u64_of(bytes[5]) << 40) |
        (int.u64_of(bytes[6]) << 48) |
        (int.u64_of(bytes[7]) << 56);
}

pub inline fn write_u16_le(bytes: []u8, value: u16) void {
    bytes[0] = int.u8_of(value);
    bytes[1] = int.u8_of(value >> 8);
}

pub inline fn write_u32_le(bytes: []u8, value: u32) void {
    bytes[0] = int.u8_of(value);
    bytes[1] = int.u8_of(value >> 8);
    bytes[2] = int.u8_of(value >> 16);
    bytes[3] = int.u8_of(value >> 24);
}

pub inline fn write_u64_le(bytes: []u8, value: u64) void {
    bytes[0] = int.u8_of(value);
    bytes[1] = int.u8_of(value >> 8);
    bytes[2] = int.u8_of(value >> 16);
    bytes[3] = int.u8_of(value >> 24);
    bytes[4] = int.u8_of(value >> 32);
    bytes[5] = int.u8_of(value >> 40);
    bytes[6] = int.u8_of(value >> 48);
    bytes[7] = int.u8_of(value >> 56);
}
