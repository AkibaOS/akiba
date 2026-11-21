//! Admit The Shipped AFS Driver With The Confirmed AHCI Endpoint

const std = @import("std");

const authority = @import("mirai").device.ahci.authority;
const guard = @import("asm").interrupts.guard;
const image = @import("mirai").bootstrap.image;
const install = @import("shared").afs.strings.install;
const kata = @import("mirai").kata;
const memory = @import("mirai").memory.allocator.native;
const postman = @import("mirai").postman;
const rollback = @import("mirai").bootstrap.strings.image.rollback;
const stack = @import("mirai").bootstrap.constants.driver.afs;
const storage = @import("mirai").bootstrap.storage.handoff;

const Image = @import("mirai").bootstrap.types.driver.image.Image;
const Kata = kata.types.kata.Kata;
const Mount = @import("shared").afs.types.service.mount.Mount;
const Started = @import("mirai").bootstrap.types.driver.started.Started;
const Thread = @import("mirai").thread.types.thread.Thread;

var pending: ?Image = null;
var started: ?Started = null;

pub fn arm(owner: *const Kata, bytes: []const u8) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (pending != null or started != null or owner.State != .Born or bytes.len == 0) return error.InvalidState;
    pending = .{ .PulseID = owner.ID, .Bytes = try memory.get().dupe(u8, bytes) };
}

pub fn disarm(owner: *const Kata) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const source = pending orelse return;
    if (source.PulseID != owner.ID or owner.State != .Born) return;
    pending = null;
    memory.get().free(source.Bytes);
}

pub fn start(caller: *Thread, ahci: u64) !u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    try postman.validate.current(caller);
    const disk = storage.forPulse(caller.Owner) orelse return error.InvalidCaller;
    const source = pending orelse return error.InvalidState;
    if (source.PulseID != caller.Owner.ID) return error.InvalidCaller;
    if (!authority.readyFor(caller.Owner.ID, ahci)) return error.InvalidState;
    const mount: Mount = .{ .PulseID = caller.Owner.ID, .DiskDriverID = ahci, .LastSector = disk.Volume.LastLBA - disk.Volume.FirstLBA };
    const prepared = try image.prepare.prepare(caller.Owner, source.Bytes, .{
        .StackBase = stack.BASE,
        .StackPages = stack.PAGES,
        .Startup = .{ .Identity = install.PATH, .Parameters = std.mem.asBytes(&mount) },
    });
    errdefer image.abort.abort(prepared) catch @panic(rollback.ROLLBACK_FAILED);
    try authority.bindAfs(caller.Owner.ID, ahci, prepared.Owner);
    errdefer authority.unbindAfs(prepared.Owner);
    const identifier = try image.start.start(prepared);
    started = .{ .PulseID = caller.Owner.ID, .DriverID = identifier };
    pending = null;
    memory.get().free(source.Bytes);
    return identifier;
}

pub fn confirm(caller: *Thread, identifier: u64) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    try postman.validate.current(caller);
    if (storage.forPulse(caller.Owner) == null) return error.InvalidCaller;
    const current = if (started) |*value| value else return error.InvalidState;
    if (current.Confirmed or !usable(current.*, caller.Owner.ID, identifier)) return error.InvalidState;
    current.Confirmed = true;
}

pub fn readyFor(pulse: u64, driver: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const current = started orelse return false;
    return current.Confirmed and usable(current, pulse, driver);
}

pub fn ready(pulse: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const current = started orelse return false;
    return current.Confirmed and usable(current, pulse, current.DriverID);
}

fn usable(current: Started, pulse: u64, driver: u64) bool {
    if (current.PulseID != pulse or current.DriverID != driver) return false;
    const owner = kata.state.findByID(driver) orelse return false;
    return owner.State == .Alive or owner.State == .Sleeping;
}
