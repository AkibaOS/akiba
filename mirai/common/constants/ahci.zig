//! AHCI constants

// HBA port command bits
pub const PORT_CMD_ST: u32 = 0x0001;
pub const PORT_CMD_FRE: u32 = 0x0010;
pub const PORT_CMD_FR: u32 = 0x4000;
pub const PORT_CMD_CR: u32 = 0x8000;

// Global HBA control
pub const GHC_AE: u32 = 1 << 31;

// Port interrupt status
pub const PxIS_TFES: u32 = 1 << 30;

// FIS types
pub const FIS_TYPE_REG_H2D: u8 = 0x27;
pub const FIS_TYPE_REG_D2H: u8 = 0x34;
pub const FIS_TYPE_DMA_ACT: u8 = 0x39;
pub const FIS_TYPE_DMA_SETUP: u8 = 0x41;
pub const FIS_TYPE_DATA: u8 = 0x46;
pub const FIS_TYPE_BIST: u8 = 0x58;
pub const FIS_TYPE_PIO_SETUP: u8 = 0x5F;
pub const FIS_TYPE_DEV_BITS: u8 = 0xA1;

// SSTS detection
pub const SSTS_DET_PRESENT: u8 = 3;
pub const SSTS_IPM_ACTIVE: u8 = 1;

// Port types
pub const PORT_TYPE_NONE: u32 = 0;
pub const PORT_TYPE_SATA: u32 = 1;
pub const PORT_TYPE_ATAPI: u32 = 2;
pub const PORT_TYPE_SEMB: u32 = 3;
pub const PORT_TYPE_PM: u32 = 4;

// Port offsets
pub const PORT_OFFSET_BASE: usize = 0x100;

// BAR mask
pub const BAR_MASK: u32 = 0xFFFFFFF0;

// PRDT interrupt bit
pub const PRDT_INTERRUPT: u32 = 1 << 31;

// PIC end of interrupt
pub const PIC_EOI: u8 = 0x20;
