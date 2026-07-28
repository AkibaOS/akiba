//! Hikari EFI Block I/O Types

const base = @import("hikari").efi.types.base;

pub const BlockIoMedia = extern struct {
    MediaId: u32,
    RemovableMedia: bool,
    MediaPresent: bool,
    LogicalPartition: bool,
    ReadOnly: bool,
    WriteCaching: bool,
    BlockSize: u32,
    IOAlign: u32,
    LastBlock: base.LBA,
    LowestAlignedLBA: base.LBA,
    LogicalBlocksPerPhysicalBlock: u32,
    OptimalTransferLengthGranularity: u32,
};
