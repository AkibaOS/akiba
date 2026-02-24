//! Hikari ELF Types

const constants = @import("constants.zig");

pub const Elf64Header = extern struct {
    magic: [4]u8,
    class: u8,
    data: u8,
    version: u8,
    osabi: u8,
    abi_version: u8,
    padding: [7]u8,
    elf_type: u16 align(1),
    machine: u16 align(1),
    elf_version: u32 align(1),
    entry: u64 align(1),
    program_header_offset: u64 align(1),
    section_header_offset: u64 align(1),
    flags: u32 align(1),
    header_size: u16 align(1),
    program_header_entry_size: u16 align(1),
    program_header_count: u16 align(1),
    section_header_entry_size: u16 align(1),
    section_header_count: u16 align(1),
    section_identity_index: u16 align(1),

    pub fn is_valid(self: *const Elf64Header) bool {
        if (self.magic[0] != constants.magic[0] or
            self.magic[1] != constants.magic[1] or
            self.magic[2] != constants.magic[2] or
            self.magic[3] != constants.magic[3])
        {
            return false;
        }
        if (self.class != constants.class_64) {
            return false;
        }
        if (self.data != constants.data_little_endian) {
            return false;
        }
        if (self.version != constants.version_current) {
            return false;
        }
        return true;
    }

    pub fn is_executable(self: *const Elf64Header) bool {
        return self.elf_type == constants.type_executable;
    }

    pub fn is_x86_64(self: *const Elf64Header) bool {
        return self.machine == constants.machine_x86_64;
    }

    pub fn get_program_headers(self: *const Elf64Header, base: [*]const u8) []const Elf64ProgramHeader {
        const phdr_ptr: [*]const Elf64ProgramHeader = @ptrCast(@alignCast(base + self.program_header_offset));
        return phdr_ptr[0..self.program_header_count];
    }

    pub fn get_section_headers(self: *const Elf64Header, base: [*]const u8) []const Elf64SectionHeader {
        const shdr_ptr: [*]const Elf64SectionHeader = @ptrCast(@alignCast(base + self.section_header_offset));
        return shdr_ptr[0..self.section_header_count];
    }
};

pub const Elf64ProgramHeader = extern struct {
    segment_type: u32 align(1),
    flags: u32 align(1),
    offset: u64 align(1),
    virtual_address: u64 align(1),
    physical_address: u64 align(1),
    unit_size: u64 align(1),
    memory_size: u64 align(1),
    alignment: u64 align(1),

    pub fn is_loadable(self: *const Elf64ProgramHeader) bool {
        return self.segment_type == constants.segment_load;
    }

    pub fn is_executable(self: *const Elf64ProgramHeader) bool {
        return (self.flags & constants.segment_flag_execute) != 0;
    }

    pub fn is_writable(self: *const Elf64ProgramHeader) bool {
        return (self.flags & constants.segment_flag_write) != 0;
    }

    pub fn is_readable(self: *const Elf64ProgramHeader) bool {
        return (self.flags & constants.segment_flag_read) != 0;
    }

    pub fn get_data(self: *const Elf64ProgramHeader, base: [*]const u8) []const u8 {
        return (base + self.offset)[0..self.unit_size];
    }
};

pub const Elf64SectionHeader = extern struct {
    identity_offset: u32 align(1),
    section_type: u32 align(1),
    flags: u64 align(1),
    address: u64 align(1),
    offset: u64 align(1),
    size: u64 align(1),
    link: u32 align(1),
    info: u32 align(1),
    address_alignment: u64 align(1),
    entry_size: u64 align(1),

    pub fn is_allocatable(self: *const Elf64SectionHeader) bool {
        return (self.flags & constants.section_flag_alloc) != 0;
    }

    pub fn is_writable(self: *const Elf64SectionHeader) bool {
        return (self.flags & constants.section_flag_write) != 0;
    }

    pub fn is_executable(self: *const Elf64SectionHeader) bool {
        return (self.flags & constants.section_flag_execinstr) != 0;
    }

    pub fn is_nobits(self: *const Elf64SectionHeader) bool {
        return self.section_type == constants.section_nobits;
    }

    pub fn get_data(self: *const Elf64SectionHeader, base: [*]const u8) []const u8 {
        return (base + self.offset)[0..self.size];
    }
};

pub const Elf64Symbol = extern struct {
    identity_offset: u32 align(1),
    info: u8,
    other: u8,
    section_index: u16 align(1),
    value: u64 align(1),
    size: u64 align(1),

    pub fn get_binding(self: *const Elf64Symbol) u8 {
        return self.info >> 4;
    }

    pub fn get_type(self: *const Elf64Symbol) u8 {
        return self.info & 0x0F;
    }

    pub fn get_visibility(self: *const Elf64Symbol) u8 {
        return self.other & 0x03;
    }
};

pub const Elf64Rela = extern struct {
    offset: u64 align(1),
    info: u64 align(1),
    addend: i64 align(1),

    pub fn get_symbol(self: *const Elf64Rela) u32 {
        return @truncate(self.info >> 32);
    }

    pub fn get_type(self: *const Elf64Rela) u32 {
        return @truncate(self.info & 0xFFFFFFFF);
    }
};

pub const LoadedSegment = struct {
    virtual_address: u64,
    physical_address: u64,
    memory_size: u64,
    flags: u32,
};

pub const LoadedImage = struct {
    entry_point: u64,
    base_address: u64,
    end_address: u64,
    segments: [16]LoadedSegment,
    segment_count: usize,

    pub fn total_size(self: *const LoadedImage) u64 {
        return self.end_address - self.base_address;
    }
};
