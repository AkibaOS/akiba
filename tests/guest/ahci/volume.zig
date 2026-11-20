//! Compare Native AHCI GPT Sectors With The Retained Boot Volume

const identity = @import("shared").gpt.read.identity;
const transfer = @import("tests").guest.ahci.transfer;
const wire = @import("shared").ahci.constants.command.dma;

const Disk = @import("tests").guest.types.ahci.disk.Disk;
const VerifyError = @import("shared").gpt.errors.read.verification.VerifyError;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn match(disk: *Disk, volume: Volume) anyerror!bool {
    var scratch: [wire.SECTOR_BYTES]u8 = undefined;
    return identity.matchSectors(volume, .{
        .Context = disk,
        .Read = read,
        .BlockBytes = wire.SECTOR_BYTES,
        .LastLBA = disk.Sectors - 1,
    }, &scratch);
}

fn read(context: *anyopaque, lba: u64, destination: []u8) !void {
    if (destination.len != wire.SECTOR_BYTES) return VerifyError.InvalidSource;
    const disk: *const Disk = @ptrCast(@alignCast(context));
    try transfer.read(disk, lba, destination[0..wire.SECTOR_BYTES]);
}
