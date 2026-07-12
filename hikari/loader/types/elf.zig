//! Hikari ELF Types

const constants = @import("../constants/constants.zig");

pub const Elf64Header = extern struct {
    Magic: [4]u8,
    Class: u8,
    Data: u8,
    Version: u8,
    OSABI: u8,
    ABIVersion: u8,
    Padding: [7]u8,
    ElfType: u16 align(1),
    Machine: u16 align(1),
    ElfVersion: u32 align(1),
    Entry: u64 align(1),
    ProgramHeaderOffset: u64 align(1),
    SectionHeaderOffset: u64 align(1),
    Flags: u32 align(1),
    HeaderSize: u16 align(1),
    ProgramHeaderEntrySize: u16 align(1),
    ProgramHeaderCount: u16 align(1),
    SectionHeaderEntrySize: u16 align(1),
    SectionHeaderCount: u16 align(1),
    SectionIdentityIndex: u16 align(1),

    pub fn isValid(self: *const Elf64Header) bool {
        if (self.Magic[0] != constants.elf.MAGIC[0] or
            self.Magic[1] != constants.elf.MAGIC[1] or
            self.Magic[2] != constants.elf.MAGIC[2] or
            self.Magic[3] != constants.elf.MAGIC[3])
        {
            return false;
        }
        if (self.Class != constants.elf.CLASS_64) {
            return false;
        }
        if (self.Data != constants.elf.DATA_LITTLE_ENDIAN) {
            return false;
        }
        if (self.Version != constants.elf.VERSION_CURRENT) {
            return false;
        }
        return true;
    }

    pub fn isExecutable(self: *const Elf64Header) bool {
        return self.ElfType == constants.elf.TYPE_EXECUTABLE;
    }

    pub fn isX8664(self: *const Elf64Header) bool {
        return self.Machine == constants.elf.MACHINE_X86_64;
    }

    pub fn getProgramHeaders(self: *const Elf64Header, base: [*]const u8) []const Elf64ProgramHeader {
        const program_header_pointer: [*]const Elf64ProgramHeader = @ptrCast(@alignCast(base + self.ProgramHeaderOffset));
        return program_header_pointer[0..self.ProgramHeaderCount];
    }

    pub fn getSectionHeaders(self: *const Elf64Header, base: [*]const u8) []const Elf64SectionHeader {
        const section_header_pointer: [*]const Elf64SectionHeader = @ptrCast(@alignCast(base + self.SectionHeaderOffset));
        return section_header_pointer[0..self.SectionHeaderCount];
    }
};

pub const Elf64ProgramHeader = extern struct {
    SegmentType: u32 align(1),
    Flags: u32 align(1),
    Offset: u64 align(1),
    VirtualAddress: u64 align(1),
    PhysicalAddress: u64 align(1),
    UnitSize: u64 align(1),
    MemorySize: u64 align(1),
    Alignment: u64 align(1),

    pub fn isLoadable(self: *const Elf64ProgramHeader) bool {
        return self.SegmentType == constants.elf.SEGMENT_LOAD;
    }

    pub fn isExecutable(self: *const Elf64ProgramHeader) bool {
        return (self.Flags & constants.elf.SEGMENT_FLAG_EXECUTE) != 0;
    }

    pub fn isWritable(self: *const Elf64ProgramHeader) bool {
        return (self.Flags & constants.elf.SEGMENT_FLAG_WRITE) != 0;
    }

    pub fn isReadable(self: *const Elf64ProgramHeader) bool {
        return (self.Flags & constants.elf.SEGMENT_FLAG_READ) != 0;
    }

    pub fn getData(self: *const Elf64ProgramHeader, base: [*]const u8) []const u8 {
        return (base + self.Offset)[0..self.UnitSize];
    }
};

pub const Elf64SectionHeader = extern struct {
    IdentityOffset: u32 align(1),
    SectionType: u32 align(1),
    Flags: u64 align(1),
    Address: u64 align(1),
    Offset: u64 align(1),
    Size: u64 align(1),
    Link: u32 align(1),
    Info: u32 align(1),
    AddressAlignment: u64 align(1),
    EntrySize: u64 align(1),

    pub fn isAllocatable(self: *const Elf64SectionHeader) bool {
        return (self.Flags & constants.elf.SECTION_FLAG_ALLOC) != 0;
    }

    pub fn isWritable(self: *const Elf64SectionHeader) bool {
        return (self.Flags & constants.elf.SECTION_FLAG_WRITE) != 0;
    }

    pub fn isExecutable(self: *const Elf64SectionHeader) bool {
        return (self.Flags & constants.elf.SECTION_FLAG_EXECINSTR) != 0;
    }

    pub fn isNobits(self: *const Elf64SectionHeader) bool {
        return self.SectionType == constants.elf.SECTION_NOBITS;
    }

    pub fn getData(self: *const Elf64SectionHeader, base: [*]const u8) []const u8 {
        return (base + self.Offset)[0..self.Size];
    }
};

pub const Elf64Symbol = extern struct {
    IdentityOffset: u32 align(1),
    Info: u8,
    Other: u8,
    SectionIndex: u16 align(1),
    Value: u64 align(1),
    Size: u64 align(1),

    pub fn getBinding(self: *const Elf64Symbol) u8 {
        return self.Info >> constants.elf.SYMBOL_BINDING_SHIFT;
    }

    pub fn getType(self: *const Elf64Symbol) u8 {
        return self.Info & constants.elf.SYMBOL_TYPE_MASK;
    }

    pub fn getVisibility(self: *const Elf64Symbol) u8 {
        return self.Other & constants.elf.SYMBOL_VISIBILITY_MASK;
    }
};

pub const Elf64Rela = extern struct {
    Offset: u64 align(1),
    Info: u64 align(1),
    Addend: i64 align(1),

    pub fn getSymbol(self: *const Elf64Rela) u32 {
        return @truncate(self.Info >> @bitSizeOf(u32));
    }

    pub fn getType(self: *const Elf64Rela) u32 {
        return @truncate(self.Info);
    }
};

pub const LoadedSegment = struct {
    VirtualAddress: u64,
    PhysicalAddress: u64,
    MemorySize: u64,
    Flags: u32,
};

pub const LoadedImage = struct {
    EntryPoint: u64,
    BaseAddress: u64,
    EndAddress: u64,
    Segments: [constants.elf.MAX_SEGMENTS]LoadedSegment,
    SegmentCount: usize,

    pub fn totalSize(self: *const LoadedImage) u64 {
        return self.EndAddress - self.BaseAddress;
    }
};
