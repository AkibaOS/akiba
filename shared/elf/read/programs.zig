//! Bounded ELF Program Table Reading

const constants = @import("shared").elf.constants.format;
const types = @import("shared").elf.types.format;
const ImageError = @import("shared").elf.errors.image.ImageError;

pub fn read(data: []const u8, value: *const types.Elf64Header) ImageError![]const types.Elf64ProgramHeader {
    if (value.ProgramHeaderCount == 0) return ImageError.NoLoadableSegments;
    if (value.ProgramHeaderCount == constants.PROGRAM_COUNT_EXTENDED or
        value.ProgramHeaderEntrySize != constants.PROGRAM_BYTES or value.ProgramHeaderOffset < value.HeaderSize or
        value.ProgramHeaderOffset > data.len) return ImageError.InvalidProgramHeaders;
    const offset: usize = @intCast(value.ProgramHeaderOffset);
    const length = @as(usize, value.ProgramHeaderCount) * constants.PROGRAM_BYTES;
    if (length > data.len - offset) return ImageError.InvalidProgramHeaders;
    const table: [*]const types.Elf64ProgramHeader = @ptrCast(data.ptr + offset);
    return table[0..value.ProgramHeaderCount];
}
