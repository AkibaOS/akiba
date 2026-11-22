//! AHCI Port Link And Device Signature Fields

pub const PRESENCE_MASK: u32 = 0xf;
pub const NO_DEVICE: u32 = 0;
pub const ESTABLISHED: u32 = 3;
pub const POWER_MASK: u32 = 0xf00;
pub const ACTIVE: u32 = 0x100;
pub const ATA_SIGNATURE: u32 = 0x00000101;
pub const PACKET_SIGNATURE: u32 = 0xeb140101;
pub const INITIAL_SIGNATURE: u32 = 0xffffffff;
