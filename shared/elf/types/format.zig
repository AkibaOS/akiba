//! ELF64 Header And Program Wire Types

const constants = @import("shared").elf.constants.format;

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
        for (constants.MAGIC, self.Magic) |expected, actual| {
            if (expected != actual) return false;
        }
        return self.Class == constants.CLASS_64 and self.Data == constants.DATA_LITTLE_ENDIAN and
            self.Version == constants.VERSION_CURRENT;
    }

    pub fn isExecutable(self: *const Elf64Header) bool {
        return self.ElfType == constants.TYPE_EXECUTABLE;
    }

    pub fn isX8664(self: *const Elf64Header) bool {
        return self.Machine == constants.MACHINE_X86_64;
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
        return self.SegmentType == constants.SEGMENT_LOAD;
    }

    pub fn isExecutable(self: *const Elf64ProgramHeader) bool {
        return (self.Flags & constants.SEGMENT_FLAG_EXECUTE) != 0;
    }

    pub fn isWritable(self: *const Elf64ProgramHeader) bool {
        return (self.Flags & constants.SEGMENT_FLAG_WRITE) != 0;
    }

    pub fn isReadable(self: *const Elf64ProgramHeader) bool {
        return (self.Flags & constants.SEGMENT_FLAG_READ) != 0;
    }
};
