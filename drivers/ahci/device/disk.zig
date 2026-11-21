//! Verify The AHCI Driver Is Serving The Original Boot Disk

const ahci = @import("shared").ahci;
const gpt = @import("shared").gpt.read.identity;
const invoke = @import("personaasm").invoke;

const Description = ahci.types.device.invocation.Description;
const DiskError = @import("ahci").errors.device.disk.DiskError;
const Operation = ahci.types.device.invocation.Operation;
const Source = @import("shared").storage.types.sector.Source;
const Status = @import("shared").persona.types.invocation.Status;
const wire = ahci.constants.command.dma;

pub fn verify() !Description {
    var description: Description = undefined;
    try call(.Describe, @intFromPtr(&description), 0);
    if (description.PulseID == 0 or description.Volume.BlockBytes != wire.SECTOR_BYTES or !description.Volume.isValid())
        return DiskError.VolumeMismatch;
    var scratch: [wire.SECTOR_BYTES]u8 = undefined;
    try call(.Identify, @intFromPtr(&scratch), 0);
    const sectors = try ahci.command.identify.capacity(&scratch);
    const source: Source = .{ .Context = &description, .Read = read, .BlockBytes = wire.SECTOR_BYTES, .LastLBA = sectors - 1 };
    if (!try gpt.matchSectors(description.Volume, source, &scratch)) return DiskError.VolumeMismatch;
    try call(.Confirm, 0, 0);
    return description;
}

pub fn readSector(lba: u64, block: []u8) DiskError!void {
    if (block.len != wire.SECTOR_BYTES) return DiskError.InvalidSectorBuffer;
    try call(.Read, lba, @intFromPtr(block.ptr));
}

fn read(_: *anyopaque, lba: u64, block: []u8) !void {
    try readSector(lba, block);
}

fn call(operation: Operation, first: u64, second: u64) DiskError!void {
    const result = invoke.call(.Ahci, @intFromEnum(operation), first, second, 0);
    if (result.Status != @intFromEnum(Status.Success)) return DiskError.DeviceRefused;
}
