//! Hikari ELF Constants

pub const MAGIC: [4]u8 = .{ 0x7F, 'E', 'L', 'F' };

pub const CLASS_NONE: u8 = 0;
pub const CLASS_32: u8 = 1;
pub const CLASS_64: u8 = 2;

pub const DATA_NONE: u8 = 0;
pub const DATA_LITTLE_ENDIAN: u8 = 1;
pub const DATA_BIG_ENDIAN: u8 = 2;

pub const VERSION_NONE: u8 = 0;
pub const VERSION_CURRENT: u8 = 1;

pub const OSABI_NONE: u8 = 0;
pub const OSABI_SYSV: u8 = 0;
pub const OSABI_LINUX: u8 = 3;
pub const OSABI_FREEBSD: u8 = 9;
pub const OSABI_STANDALONE: u8 = 255;

pub const TYPE_NONE: u16 = 0;
pub const TYPE_RELOCATABLE: u16 = 1;
pub const TYPE_EXECUTABLE: u16 = 2;
pub const TYPE_SHARED: u16 = 3;
pub const TYPE_CORE: u16 = 4;

pub const MACHINE_NONE: u16 = 0;
pub const MACHINE_386: u16 = 3;
pub const MACHINE_X86_64: u16 = 62;
pub const MACHINE_AARCH64: u16 = 183;
pub const MACHINE_RISCV: u16 = 243;

pub const SEGMENT_NULL: u32 = 0;
pub const SEGMENT_LOAD: u32 = 1;
pub const SEGMENT_DYNAMIC: u32 = 2;
pub const SEGMENT_INTERP: u32 = 3;
pub const SEGMENT_NOTE: u32 = 4;
pub const SEGMENT_SHLIB: u32 = 5;
pub const SEGMENT_PHDR: u32 = 6;
pub const SEGMENT_TLS: u32 = 7;
pub const SEGMENT_GNU_EH_FRAME: u32 = 0x6474E550;
pub const SEGMENT_GNU_STACK: u32 = 0x6474E551;
pub const SEGMENT_GNU_RELRO: u32 = 0x6474E552;

pub const SEGMENT_FLAG_EXECUTE: u32 = 0x1;
pub const SEGMENT_FLAG_WRITE: u32 = 0x2;
pub const SEGMENT_FLAG_READ: u32 = 0x4;

pub const SECTION_NULL: u32 = 0;
pub const SECTION_PROGBITS: u32 = 1;
pub const SECTION_SYMTAB: u32 = 2;
pub const SECTION_STRTAB: u32 = 3;
pub const SECTION_RELA: u32 = 4;
pub const SECTION_HASH: u32 = 5;
pub const SECTION_DYNAMIC: u32 = 6;
pub const SECTION_NOTE: u32 = 7;
pub const SECTION_NOBITS: u32 = 8;
pub const SECTION_REL: u32 = 9;
pub const SECTION_SHLIB: u32 = 10;
pub const SECTION_DYNSYM: u32 = 11;
pub const SECTION_INIT_ARRAY: u32 = 14;
pub const SECTION_FINI_ARRAY: u32 = 15;
pub const SECTION_PREINIT_ARRAY: u32 = 16;
pub const SECTION_GROUP: u32 = 17;
pub const SECTION_SYMTAB_SHNDX: u32 = 18;

pub const SECTION_FLAG_WRITE: u64 = 0x1;
pub const SECTION_FLAG_ALLOC: u64 = 0x2;
pub const SECTION_FLAG_EXECINSTR: u64 = 0x4;
pub const SECTION_FLAG_MERGE: u64 = 0x10;
pub const SECTION_FLAG_STRINGS: u64 = 0x20;
pub const SECTION_FLAG_INFO_LINK: u64 = 0x40;
pub const SECTION_FLAG_LINK_ORDER: u64 = 0x80;
pub const SECTION_FLAG_OS_NONCONFORMING: u64 = 0x100;
pub const SECTION_FLAG_GROUP: u64 = 0x200;
pub const SECTION_FLAG_TLS: u64 = 0x400;

pub const SECTION_INDEX_UNDEFINED: u16 = 0;
pub const SECTION_INDEX_ABS: u16 = 0xFFF1;
pub const SECTION_INDEX_COMMON: u16 = 0xFFF2;

pub const ELF64_HEADER_SIZE: usize = 64;
pub const ELF64_PROGRAM_HEADER_SIZE: usize = 56;
pub const ELF64_SECTION_HEADER_SIZE: usize = 64;

pub const MAX_SEGMENTS: usize = 16;

pub const SYMBOL_BINDING_SHIFT: u3 = 4;
pub const SYMBOL_TYPE_MASK: u8 = 0x0F;
pub const SYMBOL_VISIBILITY_MASK: u8 = 0x03;
