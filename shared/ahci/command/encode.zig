//! Encode A Single Read Only AHCI Transfer

const std = @import("std");

const ahci = @import("shared").ahci;
const sizes = @import("common").constants.memory.sizes;

const CommandError = ahci.errors.command.transfer.CommandError;
const Operation = ahci.types.command.operation.Operation;
const ata = ahci.constants.command.ata;
const dma = ahci.constants.command.dma;

pub fn prepare(page: *[sizes.PAGE_SIZE]u8, physical: u64, operation: Operation) CommandError!void {
    if (physical == 0 or physical & sizes.PAGE_MASK != 0 or physical > dma.DMA_LIMIT - sizes.PAGE_SIZE)
        return error.InvalidDmaPage;
    if (operation == .Read and operation.Read >= ata.LBA_LIMIT) return error.InvalidSector;
    @memset(page[0..dma.FIS_OFFSET], 0);
    @memset(page[dma.TABLE_OFFSET..], 0);
    word(page, 0, dma.HEADER_FLAGS);
    word(page, dma.HEADER_TABLE_ADDRESS, @intCast(physical + dma.TABLE_OFFSET));
    word(page, dma.PRD_OFFSET, @intCast(physical + dma.DATA_OFFSET));
    word(page, dma.PRD_LENGTH_OFFSET, dma.SECTOR_BYTES - 1);
    const frame = page[dma.TABLE_OFFSET..][0..20];
    frame[0] = ata.REGISTER_FIS;
    frame[1] = ata.COMMAND_FRAME;
    switch (operation) {
        .Identify => frame[2] = ata.IDENTIFY,
        .Read => |sector| {
            frame[2] = ata.READ_DMA_EXT;
            std.mem.writeInt(u24, frame[4..7], @truncate(sector), .little);
            frame[7] = ata.LBA_MODE;
            std.mem.writeInt(u24, frame[8..11], @intCast(sector >> 24), .little);
            frame[12] = 1;
        },
    }
}

fn word(page: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, page[offset..][0..4], value, .little);
}
