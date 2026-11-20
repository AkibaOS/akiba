//! Encode A Single Read Transfer And Parse Disk Geometry

const std = @import("std");

const ahci = @import("shared").ahci;
const sizes = @import("common").constants.memory.sizes;

const CommandError = ahci.errors.command.CommandError;
const Operation = ahci.types.command.Operation;
const values = ahci.constants.command;

pub fn prepare(page: *[sizes.PAGE_SIZE]u8, physical: u64, operation: Operation) CommandError!void {
    if (physical == 0 or physical & sizes.PAGE_MASK != 0 or physical > values.DMA_LIMIT - sizes.PAGE_SIZE)
        return error.InvalidDmaPage;
    if (operation == .Read and operation.Read >= values.LBA_LIMIT) return error.InvalidSector;
    @memset(page[0..values.FIS_OFFSET], 0);
    @memset(page[values.TABLE_OFFSET..], 0);
    word(page, 0, values.HEADER_FLAGS);
    word(page, values.HEADER_TABLE_ADDRESS, @intCast(physical + values.TABLE_OFFSET));
    word(page, values.PRD_OFFSET, @intCast(physical + values.DATA_OFFSET));
    word(page, values.PRD_LENGTH_OFFSET, values.SECTOR_BYTES - 1);
    const frame = page[values.TABLE_OFFSET..][0..20];
    frame[0] = values.REGISTER_FIS;
    frame[1] = values.COMMAND_FRAME;
    switch (operation) {
        .Identify => frame[2] = values.IDENTIFY,
        .Read => |sector| {
            frame[2] = values.READ_DMA_EXT;
            std.mem.writeInt(u24, frame[4..7], @truncate(sector), .little);
            frame[7] = values.LBA_MODE;
            std.mem.writeInt(u24, frame[8..11], @intCast(sector >> 24), .little);
            frame[12] = 1;
        },
    }
}

pub fn capacity(identity: *const [values.SECTOR_BYTES]u8) CommandError!u64 {
    const features = std.mem.readInt(u16, identity[values.FEATURES_OFFSET..][0..2], .little);
    if (features & values.WORD_VALID_MASK != values.WORD_VALID or features & values.LBA48 == 0) return error.UnsupportedDisk;
    const geometry = std.mem.readInt(u16, identity[values.GEOMETRY_OFFSET..][0..2], .little);
    if (geometry & values.WORD_VALID_MASK == values.WORD_VALID and geometry & values.LONG_LOGICAL_SECTOR != 0)
        return error.UnsupportedSectorSize;
    const count = std.mem.readInt(u64, identity[values.CAPACITY_OFFSET..][0..8], .little);
    if (count == 0 or count > values.LBA_LIMIT) return error.UnsupportedDisk;
    return count;
}

fn word(page: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, page[offset..][0..4], value, .little);
}
