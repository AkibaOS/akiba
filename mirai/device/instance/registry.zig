//! Boot Device Registration And Exclusive Kata Assignments

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const limits = @import("mirai").device.constants.instance.limits;
const state = @import("mirai").kata.state;

const Instance = @import("mirai").device.types.instance.record.Instance;
const Kata = @import("mirai").kata.types.kata.Kata;
const Kind = @import("mirai").device.types.instance.record.Kind;
const Record = @import("mirai").device.types.instance.record.Record;

var records: [limits.MAX_INSTANCES]Record = undefined;
var count: usize = 0;
var last_handle: u64 = 0;

pub fn register(kind: Kind, location: u64) ?u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (find(kind, location)) |identifier| return identifier;
    if (count == records.len) return null;
    const identifier = count + 1;
    records[count] = .{ .Device = .{ .ID = identifier, .Kind = kind, .Location = location } };
    count += 1;
    return identifier;
}

pub fn find(kind: Kind, location: u64) ?u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    for (records[0..count]) |entry| {
        if (entry.Device.Kind == kind and entry.Device.Location == location) return entry.Device.ID;
    }
    return null;
}

pub fn reserve(identifier: u64, owner: *const Kata) !u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    const entry = record(identifier) orelse return error.InvalidTarget;
    if (!entry.Available) return error.InvalidTarget;
    if (!state.owns(owner) or owner.Permanent or owner.CanProvision or owner.State != .Born) return error.InvalidState;
    if (entry.Assignment != null or heldBy(owner.ID) != null) return error.Busy;
    if (last_handle == std.math.maxInt(u64)) return error.CapacityReached;
    last_handle += 1;
    entry.Assignment = .{ .Owner = owner.ID, .Handle = last_handle };
    return last_handle;
}

pub fn commit(identifier: u64) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const entry = heldBy(identifier) orelse return;
    entry.Assignment.?.Committed = true;
}

pub fn retire(identifier: u64) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const entry = heldBy(identifier) orelse return;
    entry.Assignment = null;
}

pub fn handleFor(owner: *const Kata) ?u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!state.owns(owner) or !live(owner)) return null;
    const entry = heldBy(owner.ID) orelse return null;
    const assignment = entry.Assignment.?;
    return if (entry.Available and assignment.Committed) assignment.Handle else null;
}

pub fn resolve(owner: *const Kata, handle: u64) ?Instance {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!state.owns(owner) or !live(owner)) return null;
    const entry = heldBy(owner.ID) orelse return null;
    const assignment = entry.Assignment.?;
    return if (entry.Available and assignment.Committed and assignment.Handle == handle) entry.Device else null;
}

pub fn disable(identifier: u64) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const entry = record(identifier) orelse return;
    entry.Available = false;
}

pub fn assignedOwner(identifier: u64) ?*Kata {
    const flags = guard.acquire();
    defer guard.release(flags);
    const entry = record(identifier) orelse return null;
    const assignment = entry.Assignment orelse return null;
    if (!assignment.Committed) return null;
    const kata = state.findByID(assignment.Owner) orelse return null;
    return if (live(kata)) kata else null;
}

fn heldBy(identifier: u64) ?*Record {
    for (records[0..count]) |*entry| {
        if (entry.Assignment) |assignment| if (assignment.Owner == identifier) return entry;
    }
    return null;
}

fn record(identifier: u64) ?*Record {
    if (identifier == 0 or identifier > count) return null;
    return &records[@intCast(identifier - 1)];
}

fn live(owner: *const Kata) bool {
    return owner.State == .Alive or owner.State == .Sleeping;
}
