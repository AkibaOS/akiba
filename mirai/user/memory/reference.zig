//! Keep An Immutable User Frame Without A Kata Mapping

const std = @import("std");

const access = @import("mirai").user.state.access;
const backing = @import("mirai").user.state.backing;
const checks = @import("mirai").user.state.checks;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const ledger = @import("mirai").user.state.ledger;
const release = @import("mirai").user.memory.release;
const share = @import("mirai").user.memory.share;

const Kata = @import("mirai").kata.types.kata.Kata;
const Reference = @import("mirai").user.types.backing.Reference;
const UserError = @import("mirai").user.errors.memory.UserError;

const sizes = common.constants.memory.sizes;
const layout = common.constants.memory.layout;

pub fn retain(owner: *const Kata, address: u64) UserError!Reference {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!checks.isValidOwner(owner) or owner.State == .Dead) return UserError.InvalidOwner;
    const record = ledger.find(owner, address) orelse return UserError.NotOwned;
    try access.validate(record, false);
    try backing.retainSealed(record.Backing);
    return .{ .Frame = record.Backing };
}

pub fn validate(reference: *const Reference) UserError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    _ = try access.sealedAlias(reference.Frame orelse return UserError.NotOwned);
}

pub fn matches(reference: *const Reference, expected: *const [sizes.PAGE_SIZE]u8, executable: bool) UserError!bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const frame = reference.Frame orelse return UserError.NotOwned;
    _ = try access.sealedAlias(frame);
    if (access.isExecutable(frame.Stage) != executable) return false;
    const bytes: *const [sizes.PAGE_SIZE]u8 = @ptrFromInt(layout.PHYSMAP_BASE + frame.PA);
    return std.mem.eql(u8, bytes, expected);
}

pub fn map(reference: *const Reference, receiver: *Kata, address: u64) UserError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    try share.attach(reference.Frame orelse return UserError.NotOwned, receiver, address);
}

pub fn drop(reference: *Reference) UserError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    try release.dropSealed(reference.Frame orelse return UserError.NotOwned);
    reference.Frame = null;
}
