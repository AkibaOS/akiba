//! Hikari ELF Layout And Metadata Types

const constants = @import("hikari").loader.constants;
const Program = @import("shared").elf.types.format.Elf64ProgramHeader;

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

pub const ImageLayout = struct {
    EntryPoint: u64,
    VirtualBase: u64,
    PhysicalBase: u64,
    Size: u64,
    Segments: [constants.elf.MAX_SEGMENTS]Program,
    SegmentCount: usize,
};

pub const LoadedSegment = struct {
    VirtualAddress: u64,
    PhysicalAddress: u64,
    MemorySize: u64,
    Flags: u32,
};

pub const LoadedImage = struct {
    EntryPoint: u64,
    VirtualBase: u64,
    BaseAddress: u64,
    EndAddress: u64,
    Segments: [constants.elf.MAX_SEGMENTS]LoadedSegment,
    SegmentCount: usize,

    pub fn totalSize(self: *const LoadedImage) u64 {
        return self.EndAddress - self.BaseAddress;
    }
};
