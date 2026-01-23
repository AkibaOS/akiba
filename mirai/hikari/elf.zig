//! ELF64 format parser - Reads and validates ELF binaries

const serial = @import("../drivers/serial.zig");

// ELF magic number
const ELF_MAGIC = [4]u8{ 0x7F, 'E', 'L', 'F' };

// ELF class
const ELFCLASS64 = 2;

// ELF data encoding
const ELFDATA2LSB = 1; // Little endian

// ELF type
pub const ET_EXEC = 2; // Executable file
pub const ET_DYN = 3; // Shared object (PIE)

// Program header types
pub const PT_NULL = 0;
pub const PT_LOAD = 1;
pub const PT_DYNAMIC = 2;
pub const PT_INTERP = 3;

// Program header flags
pub const PF_X = 1; // Executable
pub const PF_W = 2; // Writable
pub const PF_R = 4; // Readable

// ELF64 Header
pub const ELF64Header = extern struct {
    magic: [4]u8,
    class: u8,
    data: u8,
    version: u8,
    osabi: u8,
    abiversion: u8,
    padding: [7]u8,
    type: u16,
    machine: u16,
    version2: u32,
    entry: u64,
    phoff: u64,
    shoff: u64,
    flags: u32,
    ehsize: u16,
    phentsize: u16,
    phnum: u16,
    shentsize: u16,
    shnum: u16,
    shstrndx: u16,
};

// ELF64 Program Header
pub const ELF64ProgramHeader = extern struct {
    type: u32,
    flags: u32,
    offset: u64,
    vaddr: u64,
    paddr: u64,
    filesz: u64,
    memsz: u64,
    alignment: u64,
};

pub const ELFInfo = struct {
    entry_point: u64,
    program_headers: []const ELF64ProgramHeader,
};

pub fn parse_elf(data: []const u8) !ELFInfo {
    if (data.len < @sizeOf(ELF64Header)) {
        return error.TooSmall;
    }

    const header = @as(*const ELF64Header, @ptrCast(@alignCast(data.ptr)));

    // Validate magic
    if (header.magic[0] != ELF_MAGIC[0] or
        header.magic[1] != ELF_MAGIC[1] or
        header.magic[2] != ELF_MAGIC[2] or
        header.magic[3] != ELF_MAGIC[3])
    {
        return error.InvalidMagic;
    }

    // Validate class (64-bit)
    if (header.class != ELFCLASS64) {
        return error.Not64Bit;
    }

    // Validate endianness (little endian)
    if (header.data != ELFDATA2LSB) {
        return error.NotLittleEndian;
    }

    // Validate type (executable or PIE)
    if (header.type != ET_EXEC and header.type != ET_DYN) {
        return error.NotExecutable;
    }

    // Get program headers
    if (header.phoff + (header.phnum * header.phentsize) > data.len) {
        return error.InvalidProgramHeaders;
    }

    const ph_start = data.ptr + header.phoff;
    const ph_ptr: [*]const ELF64ProgramHeader = @ptrCast(@alignCast(ph_start));
    const program_headers = ph_ptr[0..header.phnum];

    return ELFInfo{
        .entry_point = header.entry,
        .program_headers = program_headers,
    };
}
