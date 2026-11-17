//! ELF64 Wire Constants

pub const MAGIC = [_]u8{ 0x7f, 'E', 'L', 'F' };
pub const CLASS_64: u8 = 2;
pub const DATA_LITTLE_ENDIAN: u8 = 1;
pub const VERSION_CURRENT: u32 = 1;
pub const TYPE_EXECUTABLE: u16 = 2;
pub const TYPE_DYNAMIC: u16 = 3;
pub const MACHINE_X86_64: u16 = 62;
pub const HEADER_BYTES: usize = 64;
pub const PROGRAM_BYTES: usize = 56;
pub const PROGRAM_COUNT_EXTENDED: u16 = 0xffff;
pub const SEGMENT_NULL: u32 = 0;
pub const SEGMENT_LOAD: u32 = 1;
pub const SEGMENT_DYNAMIC: u32 = 2;
pub const SEGMENT_INTERP: u32 = 3;
pub const SEGMENT_NOTE: u32 = 4;
pub const SEGMENT_PHDR: u32 = 6;
pub const SEGMENT_TLS: u32 = 7;
pub const SEGMENT_STACK: u32 = 0x6474e551;
pub const SEGMENT_FLAG_EXECUTE: u32 = 1;
pub const SEGMENT_FLAG_WRITE: u32 = 2;
pub const SEGMENT_FLAG_READ: u32 = 4;
