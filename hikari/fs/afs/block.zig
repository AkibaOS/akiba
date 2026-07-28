//! Hikari AFS Block I/O

const afs = @import("shared").afs;
const efi = @import("hikari").efi;

const BlockReader = afs.io.block.BlockReader;
const BlockError = afs.errors.block.BlockError;

pub const EfiBlockContext = struct {
    BlockIO: *efi.protocols.block.BlockIoProtocol,
    BootServices: *efi.services.boot.BootServices,
    PartitionStartLBA: u64,
    BlockSize: u32,
    CellSize: u32,
};

pub fn efiReadCell(context: *anyopaque, cell: u64, buffer: []u8) BlockError!void {
    const block_context: *EfiBlockContext = @ptrCast(@alignCast(context));

    const cell_lba = block_context.PartitionStartLBA + (cell * block_context.CellSize / block_context.BlockSize);

    const read_status = block_context.BlockIO.ReadBlocks(
        block_context.BlockIO,
        block_context.BlockIO.Media.MediaId,
        cell_lba,
        block_context.CellSize,
        buffer.ptr,
    );

    if (efi.types.base.isError(read_status)) {
        return BlockError.ReadFailed;
    }
}

pub fn createBlockReader(block_context: *EfiBlockContext, total_cells: u64) BlockReader {
    return BlockReader{
        .Context = @ptrCast(block_context),
        .ReadFn = efiReadCell,
        .CellSize = block_context.CellSize,
        .TotalCells = total_cells,
    };
}
