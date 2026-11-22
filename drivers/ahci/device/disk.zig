//! Verify And Serve The Assigned AHCI Disk In Persona

const std = @import("std");

const ahci = @import("shared").ahci;
const gpt = @import("shared").gpt.read;
const invoke = @import("personaasm").invoke;

const Description = ahci.types.device.invocation.Description;
const DiskError = @import("ahci").errors.device.disk.DiskError;
const Operation = @import("shared").device.types.operation.Operation;
const Read = ahci.types.device.invocation.Read;
const Source = @import("shared").storage.types.sector.Source;
const Status = @import("shared").persona.types.invocation.Status;
const Volume = @import("shared").boot.types.volume.Volume;
const wire = ahci.constants.command.dma;

var handle: u64 = 0;

pub fn verify() !Description {
    const lease = invoke.call(.Device, @intFromEnum(Operation.Lease), 0, 0, 0);
    if (lease.Status != @intFromEnum(Status.Success) or lease.Value == 0) return DiskError.DeviceRefused;
    handle = lease.Value;
    var description: Description = undefined;
    try call(.BlockDescribe, @intFromPtr(&description));
    if (description.PulseID == 0) return DiskError.VolumeMismatch;
    var scratch: [wire.SECTOR_BYTES]u8 = undefined;
    try call(.BlockIdentify, @intFromPtr(&scratch));
    const sectors = try ahci.command.identify.capacity(&scratch);
    const source: Source = .{ .Context = &description, .Read = read, .BlockBytes = wire.SECTOR_BYTES, .LastLBA = sectors - 1 };
    if (description.Volume.isValid()) {
        if (!try gpt.identity.matchSectors(description.Volume, source, &scratch)) return DiskError.VolumeMismatch;
    } else {
        if (!std.meta.eql(description.Volume, std.mem.zeroes(Volume))) return DiskError.VolumeMismatch;
        description.Volume = (try gpt.select.firstAfs(source, &scratch)) orelse return DiskError.VolumeMismatch;
    }
    try call(.BlockConfirm, @intFromPtr(&description.Volume));
    return description;
}

pub fn accepts(peer: u64) bool {
    call(.BlockClient, peer) catch return false;
    return true;
}

pub fn readSector(lba: u64, block: []u8) DiskError!void {
    if (block.len != wire.SECTOR_BYTES) return DiskError.InvalidSectorBuffer;
    const request: Read = .{ .Sector = lba, .Destination = @intFromPtr(block.ptr) };
    try call(.BlockRead, @intFromPtr(&request));
}

fn read(_: *anyopaque, lba: u64, block: []u8) !void {
    try readSector(lba, block);
}

fn call(operation: Operation, argument: u64) DiskError!void {
    const result = invoke.call(.Device, @intFromEnum(operation), handle, argument, 0);
    if (result.Status != @intFromEnum(Status.Success)) return DiskError.DeviceRefused;
}
