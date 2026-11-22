//! Copy Typed Assigned Block Device Invocation Data

const std = @import("std");

const copy = @import("mirai").user.copy.transfer;
const storage = @import("mirai").device.ahci.storage;
const wire = @import("shared").ahci.constants.command.dma;

const Command = @import("shared").ahci.types.command.operation.Operation;
const Disk = @import("mirai").device.types.ahci.disk.Disk;
const Operation = @import("shared").device.types.operation.Operation;
const Read = @import("shared").ahci.types.device.invocation.Read;
const Thread = @import("mirai").thread.types.thread.Thread;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn perform(caller: *Thread, operation: Operation, handle: u64, argument: u64) !void {
    const disk = try storage.authorize(caller, handle);
    switch (operation) {
        .BlockDescribe => {
            const description = storage.describe(disk);
            try copy.write(caller.Owner, argument, std.mem.asBytes(&description));
        },
        .BlockIdentify => try transfer(caller, disk, .Identify, argument),
        .BlockRead => {
            var request: Read = undefined;
            try copy.read(caller.Owner, std.mem.asBytes(&request), argument);
            try transfer(caller, disk, .{ .Read = request.Sector }, request.Destination);
        },
        .BlockConfirm => {
            var volume: Volume = undefined;
            try copy.read(caller.Owner, std.mem.asBytes(&volume), argument);
            try storage.confirmDisk(disk, volume);
        },
        .BlockClient => try storage.checkClient(disk, argument),
        else => return error.InvalidArgument,
    }
}

fn transfer(caller: *Thread, disk: *Disk, operation: Command, destination: u64) !void {
    var output: [wire.SECTOR_BYTES]u8 = undefined;
    if (!copy.validate(caller.Owner, destination, output.len, true)) return error.InvalidAddress;
    try storage.transfer(disk, operation, &output);
    try copy.write(caller.Owner, destination, &output);
}
