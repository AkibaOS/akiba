//! ELF parser

const elf_const = @import("../../common/constants/elf.zig");
const system = @import("../../system/system.zig");
const types = @import("types.zig");

pub fn parse(data: []const u8) !types.Info {
    if (data.len < @sizeOf(types.Header)) {
        return error.TooSmall;
    }

    const header = @as(*const types.Header, @ptrCast(@alignCast(data.ptr)));

    if (header.magic[0] != elf_const.MAGIC[0] or
        header.magic[1] != elf_const.MAGIC[1] or
        header.magic[2] != elf_const.MAGIC[2] or
        header.magic[3] != elf_const.MAGIC[3])
    {
        return error.InvalidMagic;
    }

    if (header.class != elf_const.CLASS_64) {
        return error.Not64Bit;
    }

    if (header.data != elf_const.DATA_LSB) {
        return error.NotLittleEndian;
    }

    if (header.type != elf_const.TYPE_EXEC and header.type != elf_const.TYPE_DYN) {
        return error.NotExecutable;
    }

    if (!system.is_valid_user_pointer(header.entry)) {
        return error.InvalidEntryPoint;
    }

    if (header.phnum == 0) {
        return error.NoProgramHeaders;
    }

    if (header.phentsize != @sizeOf(types.ProgramHeader)) {
        return error.InvalidProgramHeaderSize;
    }

    const ph_table_size = @as(u64, header.phnum) * @as(u64, header.phentsize);
    if (header.phoff + ph_table_size > data.len) {
        return error.InvalidProgramHeaders;
    }

    const ph_start = data.ptr + header.phoff;
    const ph_ptr: [*]const types.ProgramHeader = @ptrCast(@alignCast(ph_start));
    const program_headers = ph_ptr[0..header.phnum];

    for (program_headers) |phdr| {
        if (phdr.type == elf_const.PT_LOAD) {
            if (phdr.offset + phdr.filesz > data.len) {
                return error.SegmentOutOfBounds;
            }
            if (phdr.filesz > phdr.memsz) {
                return error.InvalidSegmentSize;
            }
            if (!system.is_userspace_range(phdr.vaddr, phdr.memsz)) {
                return error.SegmentAddressOutOfRange;
            }
        }
    }

    return types.Info{
        .entry_point = header.entry,
        .program_headers = program_headers,
    };
}
