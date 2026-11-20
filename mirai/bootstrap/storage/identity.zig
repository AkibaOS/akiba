//! Verify The Retained Boot Volume From An Attached Native Disk

const gpt = @import("shared").gpt.read.identity;
const transfer = @import("mirai").bootstrap.storage.transfer;
const wire = @import("shared").ahci.constants.command.dma;

const Disk = @import("mirai").bootstrap.types.storage.disk.Disk;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn compare(expected: Volume, disk: *Disk) !bool {
    var scratch: [wire.SECTOR_BYTES]u8 = undefined;
    return gpt.matchSectors(expected, transfer.source(disk), &scratch);
}
