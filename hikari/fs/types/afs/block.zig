//! EFI AFS Block Context

const efi = @import("hikari").efi;

pub const EfiBlockContext = struct {
    BlockIO: *efi.types.protocols.block.BlockIoProtocol,
    BootServices: *efi.types.services.boot.BootServices,
    PartitionStartLBA: u64,
    BlockSize: u32,
    CellSize: u32,
};
