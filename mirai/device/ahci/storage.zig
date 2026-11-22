//! Bind AHCI Backing To Registry Owned Device Assignments

const std = @import("std");

const attachment = @import("mirai").device.ahci.attachment;
const codec = @import("shared").ahci.discover.location;
const guard = @import("asm").interrupts.guard;
const identify = @import("shared").ahci.command.identify;
const instances = @import("mirai").device.instance.registry;
const kata = @import("mirai").kata;
const limits = @import("mirai").device.constants.instance.limits;
const postman = @import("mirai").postman;
const selected = @import("mirai").device.ahci.selected;
const wire = @import("shared").ahci.constants.command.dma;

const Description = @import("shared").ahci.types.device.invocation.Description;
const Disk = @import("mirai").device.types.ahci.disk.Disk;
const Handoff = @import("mirai").bootstrap.types.storage.handoff.Handoff;
const Kata = kata.types.kata.Kata;
const Operation = @import("shared").ahci.types.command.operation.Operation;
const Thread = @import("mirai").thread.types.thread.Thread;
const Volume = @import("shared").boot.types.volume.Volume;

var records: [limits.MAX_INSTANCES]?Disk = @splat(null);
var boot_instance: ?u64 = null;

pub fn locate(key: u64) !u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    const location = try codec.decode(key);
    try attachment.verifyDetached(location);
    if (instances.find(.Ahci, key)) |identifier| return identifier;
    const identifier = instances.register(.Ahci, key) orelse return error.OutOfMemory;
    records[@intCast(identifier - 1)] = .{ .ID = identifier, .Location = location };
    return identifier;
}

pub fn grant(owner: *const Kata, disk: Handoff) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (boot_instance != null) return error.InvalidState;
    const identifier = try locate(codec.encode(disk.Location));
    _ = try instances.reserve(identifier, owner);
    records[@intCast(identifier - 1)].?.Boot = disk;
    boot_instance = identifier;
}

pub fn rollback(owner: *const Kata) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (owner.State != .Born) return;
    instances.retire(owner.ID);
    if (boot_instance) |identifier| records[@intCast(identifier - 1)].?.Boot = null;
    boot_instance = null;
}

pub fn authorize(caller: *Thread, handle: u64) !*Disk {
    try postman.validate.current(caller);
    const device = instances.resolve(caller.Owner, handle) orelse return error.InvalidCaller;
    if (device.Kind != .Ahci) return error.InvalidTarget;
    const record = if (records[@intCast(device.ID - 1)]) |*value| value else return error.InvalidTarget;
    if (record.Handle != handle) {
        record.* = .{ .ID = record.ID, .Location = record.Location, .Boot = record.Boot, .Handle = handle, .PulseID = kata.completion.storage.ownerOf(caller.Owner.ID) orelse return error.InvalidCaller };
        if (record.Boot) |boot| record.Volume = boot.Volume;
    }
    return record;
}

pub fn describe(record: *const Disk) Description {
    return .{ .PulseID = record.PulseID, .Volume = record.Volume orelse std.mem.zeroes(Volume) };
}

pub fn transfer(record: *Disk, operation: Operation, output: []u8) !void {
    switch (operation) {
        .Identify => if (record.Verified) return error.InvalidState,
        .Read => |sector| {
            const last = record.LastSector orelse return error.InvalidState;
            if (sector > last) return error.InvalidArgument;
            if (record.Verified) {
                const volume = record.Volume orelse return error.InvalidState;
                if (sector < volume.FirstLBA or sector > volume.LastLBA) return error.InvalidArgument;
            }
        },
    }
    try selected.execute(record.Location, operation, output);
    if (operation == .Identify) record.LastSector = (try identify.capacity(output[0..wire.SECTOR_BYTES])) - 1;
}

pub fn confirmDisk(record: *Disk, volume: Volume) !void {
    if (record.Verified or !volume.isValid() or volume.BlockBytes != wire.SECTOR_BYTES or volume.DiskLastLBA != record.LastSector) return error.InvalidState;
    if (record.Boot) |boot| if (!std.meta.eql(boot.Volume, volume)) return error.InvalidArgument;
    try attachment.verifyDetached(record.Location);
    record.Volume = volume;
    record.Verified = true;
}

pub fn confirmDriver(pulse: u64, driver: u64) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = try forDriver(driver);
    if (record.Confirmed or !usable(record, pulse, driver)) return error.InvalidState;
    record.Confirmed = true;
}

pub fn readyFor(pulse: u64, driver: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = forDriver(driver) catch return false;
    return record.Confirmed and usable(record, pulse, driver);
}

pub fn bindAfs(pulse: u64, driver: u64, owner: *const Kata) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = try forDriver(driver);
    if (!record.Confirmed or !usable(record, pulse, driver) or record.AfsID != null or !kata.state.owns(owner) or owner.Permanent or owner.State != .Born) return error.InvalidState;
    record.AfsID = owner.ID;
}

pub fn unbindAfs(owner: *const Kata) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (owner.State != .Born) return;
    for (&records) |*entry| if (entry.*) |*record| {
        if (record.AfsID == owner.ID) record.AfsID = null;
    };
}

pub fn checkClient(record: *const Disk, peer: u64) !void {
    if (record.AfsID != peer and record.PulseID != peer) return error.InvalidCaller;
}

pub fn ready(pulse: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const owner = instances.assignedOwner(boot_instance orelse return false) orelse return false;
    return readyFor(pulse, owner.ID);
}

fn forDriver(identifier: u64) !*Disk {
    const owner = kata.state.findByID(identifier) orelse return error.InvalidTarget;
    const handle = instances.handleFor(owner) orelse return error.InvalidTarget;
    const device = instances.resolve(owner, handle) orelse return error.InvalidTarget;
    if (device.Kind != .Ahci) return error.InvalidTarget;
    return if (records[@intCast(device.ID - 1)]) |*record| record else error.InvalidTarget;
}

fn usable(record: *const Disk, pulse: u64, driver: u64) bool {
    const owner = instances.assignedOwner(record.ID) orelse return false;
    return record.Boot != null and record.Verified and record.PulseID == pulse and owner.ID == driver;
}
