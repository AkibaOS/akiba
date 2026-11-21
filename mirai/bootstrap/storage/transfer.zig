//! Adapt A Scoped AHCI Disk To Bootstrap Sector Reads

const ahci = @import("shared").ahci;
const transfer = @import("mirai").device.ahci.transfer;

const CommandError = ahci.errors.command.transfer.CommandError;
const Disk = @import("mirai").bootstrap.types.storage.disk.Disk;
const Slot = @import("mirai").device.types.ahci.slot.Slot;
const Source = @import("shared").storage.types.sector.Source;
const wire = ahci.constants.command.dma;

pub fn identify(slot: Slot) !u64 {
    var data: [wire.SECTOR_BYTES]u8 = undefined;
    try transfer.execute(slot, .Identify, &data);
    return ahci.command.identify.capacity(&data);
}

pub fn source(disk: *Disk) Source {
    return .{ .Context = disk, .Read = read, .BlockBytes = wire.SECTOR_BYTES, .LastLBA = disk.Sectors - 1 };
}

fn read(context: *anyopaque, lba: u64, block: []u8) !void {
    const disk: *const Disk = @ptrCast(@alignCast(context));
    if (lba >= disk.Sectors) return CommandError.InvalidSector;
    try transfer.execute(disk.Slot, .{ .Read = lba }, block);
}
