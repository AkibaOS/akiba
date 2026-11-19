//! Resolve One File-Backed ELF Virtual Address Interval

const std = @import("std");

const format = @import("shared").elf.constants.format;
const DynamicError = @import("shared").elf.errors.dynamic.DynamicError;
const Program = @import("shared").elf.types.format.Elf64ProgramHeader;

pub fn bytes(data: []const u8, programs: []const Program, address: u64, length: u64) DynamicError![]const u8 {
    if (length == 0 or length > std.math.maxInt(u64) - address) return error.InvalidDynamicAddress;
    const end = address + length;
    var found: ?[]const u8 = null;
    for (programs) |program| {
        if (program.SegmentType != format.SEGMENT_LOAD) continue;
        if (program.UnitSize > program.MemorySize or program.MemorySize > std.math.maxInt(u64) - program.VirtualAddress)
            return error.InvalidDynamicAddress;
        if (program.MemorySize == 0 or end <= program.VirtualAddress or address >= program.VirtualAddress + program.MemorySize) continue;
        if (found != null or address < program.VirtualAddress) return error.InvalidDynamicAddress;
        const displacement = address - program.VirtualAddress;
        if (displacement >= program.UnitSize or length > program.UnitSize - displacement or
            program.Offset > data.len or program.UnitSize > data.len - program.Offset) return error.InvalidDynamicAddress;
        const start: usize = @intCast(program.Offset + displacement);
        found = data[start..][0..@intCast(length)];
    }
    return found orelse error.InvalidDynamicAddress;
}
