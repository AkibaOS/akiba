//! ELF format constants

pub const MAGIC = [4]u8{ 0x7F, 'E', 'L', 'F' };

pub const CLASS_64: u8 = 2;
pub const DATA_LSB: u8 = 1;

pub const TYPE_EXEC: u16 = 2;
pub const TYPE_DYN: u16 = 3;

pub const PT_NULL: u32 = 0;
pub const PT_LOAD: u32 = 1;
pub const PT_DYNAMIC: u32 = 2;
pub const PT_INTERP: u32 = 3;

pub const PF_X: u32 = 1;
pub const PF_W: u32 = 2;
pub const PF_R: u32 = 4;
