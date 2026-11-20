//! Compare Native AHCI GPT Sectors With The Retained Boot Volume

const boot = @import("mirai").boot.sequence.state;
const identity = @import("shared").gpt.read.identity;
const transfer = @import("tests").guest.ahci.transfer;
const wire = @import("shared").ahci.constants.command.dma;

const Disk = @import("tests").guest.types.ahci.disk.Disk;
const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;
const VerifyError = @import("shared").gpt.errors.read.verification.VerifyError;

pub fn match(disk: *Disk) anyerror!void {
    const info = boot.getBootInfo() orelse return ProbeError.AhciBootVolumeMissing;
    const volume = info.Volume orelse return ProbeError.AhciBootVolumeMissing;
    var scratch: [wire.SECTOR_BYTES]u8 = undefined;
    const matched = try identity.matchSectors(volume, .{
        .Context = disk,
        .Read = read,
        .BlockBytes = wire.SECTOR_BYTES,
        .LastLBA = disk.Sectors - 1,
    }, &scratch);
    if (!matched) return ProbeError.AhciBootVolumeMismatch;
}

fn read(context: *anyopaque, lba: u64, destination: []u8) !void {
    if (destination.len != wire.SECTOR_BYTES) return VerifyError.InvalidSource;
    const disk: *const Disk = @ptrCast(@alignCast(context));
    try transfer.read(disk, lba, destination[0..wire.SECTOR_BYTES]);
}
