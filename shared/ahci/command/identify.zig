//! Validate The Supported ATA Identify Geometry

const std = @import("std");

const ahci = @import("shared").ahci;

const CommandError = ahci.errors.command.transfer.CommandError;
const ata = ahci.constants.command.ata;
const dma = ahci.constants.command.dma;

pub fn capacity(identity: *const [dma.SECTOR_BYTES]u8) CommandError!u64 {
    const features = std.mem.readInt(u16, identity[ata.FEATURES_OFFSET..][0..2], .little);
    if (features & ata.WORD_VALID_MASK != ata.WORD_VALID or features & ata.LBA48 == 0) return error.UnsupportedDisk;
    const geometry = std.mem.readInt(u16, identity[ata.GEOMETRY_OFFSET..][0..2], .little);
    if (geometry & ata.WORD_VALID_MASK == ata.WORD_VALID and geometry & ata.LONG_LOGICAL_SECTOR != 0)
        return error.UnsupportedSectorSize;
    const count = std.mem.readInt(u64, identity[ata.CAPACITY_OFFSET..][0..8], .little);
    if (count == 0 or count > ata.LBA_LIMIT) return error.UnsupportedDisk;
    return count;
}
