//! Hikari AFS Block I/O

const efi = @import("../../efi/efi.zig");
const shared_afs = @import("shared").afs;

const BlockReader = shared_afs.BlockReader;
const BlockError = shared_afs.BlockError;

/// EFI Block I/O context
pub const EfiBlockContext = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    boot_services: *efi.services.BootServices,
    partition_start_lba: u64,
    block_size: u32,
    cell_size: u32,
};

/// EFI block read function - implements shared BlockReader interface
pub fn efi_read_cell(context: *anyopaque, cell: u64, buffer: []u8) BlockError!void {
    const ctx: *EfiBlockContext = @ptrCast(@alignCast(context));

    const cell_lba = ctx.partition_start_lba + (cell * ctx.cell_size / ctx.block_size);

    const read_status = ctx.block_io.read_blocks(
        ctx.block_io,
        ctx.block_io.media.media_id,
        cell_lba,
        ctx.cell_size,
        buffer.ptr,
    );

    if (efi.types.is_error(read_status)) {
        return BlockError.ReadFailed;
    }
}

/// Create a BlockReader from EFI context
pub fn create_block_reader(ctx: *EfiBlockContext, total_cells: u64) BlockReader {
    return BlockReader{
        .context = @ptrCast(ctx),
        .read_fn = efi_read_cell,
        .cell_size = ctx.cell_size,
        .total_cells = total_cells,
    };
}
