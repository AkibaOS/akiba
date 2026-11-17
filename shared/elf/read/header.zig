//! Bounded ELF Header Reading

const constants = @import("shared").elf.constants.format;
const types = @import("shared").elf.types.format;
const ImageError = @import("shared").elf.errors.image.ImageError;

pub fn read(data: []const u8) ImageError!*const types.Elf64Header {
    if (data.len < constants.HEADER_BYTES) return ImageError.InvalidHeader;
    const value: *const types.Elf64Header = @ptrCast(data.ptr);
    if (!value.isValid() or value.ElfVersion != constants.VERSION_CURRENT or
        value.HeaderSize != constants.HEADER_BYTES) return ImageError.InvalidHeader;
    return value;
}
