//! Retain The Detached Boot Disk For Initial Pulse

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;

const Handoff = @import("mirai").bootstrap.types.storage.handoff.Handoff;
const Kata = kata.types.kata.Kata;
const Location = @import("shared").ahci.types.discover.selection.Location;
const Volume = @import("shared").boot.types.volume.Volume;

var boot_disk: ?Handoff = null;

pub fn arm(owner: *const Kata, location: Location, volume: Volume) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (boot_disk != null or !kata.state.owns(owner) or owner.Permanent or owner.State != .Born or
        std.math.cast(u5, location.Port) == null or !volume.isValid()) return false;
    boot_disk = .{ .PulseID = owner.ID, .Location = location, .Volume = volume };
    return true;
}

pub fn disarm(owner: *const Kata) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = boot_disk orelse return;
    if (kata.state.owns(owner) and record.PulseID == owner.ID and owner.State == .Born) boot_disk = null;
}

pub fn forPulse(owner: *const Kata) ?Handoff {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = boot_disk orelse return null;
    if (!kata.state.owns(owner) or record.PulseID != owner.ID or (owner.State != .Alive and owner.State != .Sleeping)) return null;
    return record;
}
