//! Independent AHCI Port State And Signature Samples

pub const EMPTY: u32 = 0;
pub const ACTIVE: u32 = 0x113;
pub const UNESTABLISHED: u32 = 0x101;
pub const ASLEEP: u32 = 0x613;
pub const ATA_DISK: u32 = 0x00000101;
pub const OPTICAL: u32 = 0xeb140101;
pub const UNRECOGNIZED: u32 = 0x5a5a0101;
pub const INITIAL: u32 = 0xffffffff;
