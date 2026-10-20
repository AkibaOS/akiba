//! Hikari Partition Information

const efi = @import("hikari").efi;

pub const PartitionInfo = struct {
    BlockIO: *efi.types.protocols.block.BlockIoProtocol,
    StartLBA: u64,
    EndLBA: u64,
};
