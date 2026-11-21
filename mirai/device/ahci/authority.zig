//! Restrict AHCI Access To The Exact Initial Driver And Disk

const attachment = @import("mirai").device.ahci.attachment;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const postman = @import("mirai").postman;
const selected = @import("mirai").device.ahci.selected;

const Description = @import("shared").ahci.types.device.invocation.Description;
const Grant = @import("mirai").device.types.ahci.grant.Grant;
const Handoff = @import("mirai").bootstrap.types.storage.handoff.Handoff;
const Kata = kata.types.kata.Kata;
const Operation = @import("shared").ahci.types.command.operation.Operation;
const Thread = @import("mirai").thread.types.thread.Thread;

var assigned: ?Grant = null;

pub fn grant(owner: *const Kata, disk: Handoff) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (assigned != null or !kata.state.owns(owner) or owner.Permanent or owner.State != .Born) return error.InvalidState;
    try attachment.verifyDetached(disk.Location);
    assigned = .{ .OwnerID = owner.ID, .Disk = disk };
}

pub fn rollback(owner: *const Kata) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const current = assigned orelse return;
    if (current.OwnerID == owner.ID and owner.State == .Born) assigned = null;
}

pub fn authorize(caller: *Thread) !*Grant {
    try postman.validate.current(caller);
    const record = if (assigned) |*current| current else return error.InvalidCaller;
    if (record.OwnerID != caller.Owner.ID) return error.InvalidCaller;
    return record;
}

pub fn describe(record: *const Grant) Description {
    return .{ .PulseID = record.Disk.PulseID, .Volume = record.Disk.Volume };
}

pub fn transfer(record: *const Grant, operation: Operation, output: []u8) !void {
    const volume = record.Disk.Volume;
    switch (operation) {
        .Identify => if (record.Verified) return error.InvalidState,
        .Read => |sector| {
            if (sector > volume.DiskLastLBA or
                (record.Verified and (sector < volume.FirstLBA or sector > volume.LastLBA))) return error.InvalidArgument;
        },
    }
    try selected.execute(record.Disk.Location, operation, output);
}

pub fn confirmDisk(record: *Grant) !void {
    if (record.Verified) return error.InvalidState;
    try attachment.verifyDetached(record.Disk.Location);
    record.Verified = true;
}

pub fn confirmDriver(pulse: u64, driver: u64) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = if (assigned) |*current| current else return error.InvalidState;
    if (record.Confirmed or !usable(record.*, pulse, driver)) return error.InvalidState;
    record.Confirmed = true;
}

pub fn readyFor(pulse: u64, driver: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = assigned orelse return false;
    return record.Confirmed and usable(record, pulse, driver);
}

pub fn bindAfs(pulse: u64, driver: u64, owner: *const Kata) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = if (assigned) |*current| current else return error.InvalidState;
    if (!record.Confirmed or !usable(record.*, pulse, driver) or record.AfsID != null or
        !kata.state.owns(owner) or owner.Permanent or owner.State != .Born) return error.InvalidState;
    record.AfsID = owner.ID;
}

pub fn unbindAfs(owner: *const Kata) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = if (assigned) |*current| current else return;
    if (record.AfsID == owner.ID and owner.State == .Born) record.AfsID = null;
}

pub fn checkClient(record: *const Grant, peer: u64) !void {
    if (record.AfsID != peer and record.Disk.PulseID != peer) return error.InvalidCaller;
}

pub fn ready(pulse: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = assigned orelse return false;
    return record.Confirmed and usable(record, pulse, record.OwnerID);
}

fn usable(record: Grant, pulse: u64, driver: u64) bool {
    if (!record.Verified or record.Disk.PulseID != pulse or record.OwnerID != driver) return false;
    const owner = kata.state.findByID(driver) orelse return false;
    return owner.State == .Alive or owner.State == .Sleeping;
}
