//! Validated Physmap User Transfers

const std = @import("std");

const checks = @import("mirai").user.state.checks;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const ledger = @import("mirai").user.state.ledger;
const limits = @import("mirai").user.constants.limits;
const types = @import("mirai").user.types;
const usererrors = @import("mirai").user.errors.memory;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const Kata = kata.types.kata.Kata;
const Plan = types.copy.Plan;
const Record = types.record.Record;
const UserError = usererrors.UserError;

pub fn read(owner: *const Kata, destination: []u8, user_address: u64) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const plan = try prepare(owner, user_address, destination.len, false);
    var snapshot: [limits.MAX_COPY_BYTES]u8 = undefined;
    var offset: usize = 0;
    for (plan.Segments[0..plan.Count]) |segment| {
        const source: [*]const u8 = @ptrFromInt(segment.Alias);
        @memcpy(snapshot[offset..][0..segment.Length], source[0..segment.Length]);
        offset += segment.Length;
    }
    move(destination, snapshot[0..destination.len]);
}

pub fn write(owner: *const Kata, user_address: u64, source: []const u8) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const plan = try prepare(owner, user_address, source.len, true);
    var snapshot: [limits.MAX_COPY_BYTES]u8 = undefined;
    move(snapshot[0..source.len], source);
    var offset: usize = 0;
    for (plan.Segments[0..plan.Count]) |segment| {
        const destination: [*]u8 = @ptrFromInt(segment.Alias);
        @memcpy(destination[0..segment.Length], snapshot[offset..][0..segment.Length]);
        offset += segment.Length;
    }
}

pub fn validate(owner: *const Kata, address: u64, length: usize, write_access: bool) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    _ = prepare(owner, address, length, write_access) catch return false;
    return true;
}

fn prepare(owner: *const Kata, address: u64, length: usize, write_access: bool) UserError!Plan {
    if (length > limits.MAX_COPY_BYTES) return UserError.CopyTooLarge;
    if (!checks.isValidOwner(owner)) return UserError.InvalidOwner;
    if (!checks.isValidRange(address, length)) return UserError.InvalidUserRange;
    var plan = Plan{};
    if (length == 0) return plan;
    var current_address = address;
    var remaining = length;
    while (remaining != 0) {
        if (plan.Count == plan.Segments.len) return UserError.CopyTooLarge;
        const record = ledger.find(owner, current_address & ~sizes.PAGE_MASK) orelse return UserError.NotOwned;
        try validatePage(record, write_access);
        const length_in_page: usize = @intCast(@min(remaining, sizes.PAGE_SIZE - (current_address & sizes.PAGE_MASK)));
        plan.Segments[plan.Count] = .{
            .Alias = layout.PHYSMAP_BASE + record.PA + (current_address & sizes.PAGE_MASK),
            .Length = length_in_page,
        };
        plan.Count += 1;
        current_address += length_in_page;
        remaining -= length_in_page;
    }
    return plan;
}

fn validatePage(record: *const Record, write_access: bool) UserError!void {
    const resolved = checks.lookupOwned(record) orelse return UserError.InvalidOwnedMapping;
    if (write_access and record.Stage == .Sealed) return UserError.SealedPage;
    const loading = record.Stage == .Loading;
    if ((loading and (resolved.Executable or !resolved.Entry.NoExecute)) or
        (!loading and (resolved.Writable or resolved.Entry.Writable))) return UserError.InvalidOwnedMapping;
    const alias = checks.lookupAlias(record) orelse return UserError.InvalidPhysmap;
    if (alias.Writable != loading or alias.Entry.Writable != loading) return UserError.InvalidPhysmap;
    if (write_access and (!resolved.Writable or resolved.Executable or !alias.Writable)) return UserError.PermissionDenied;
}

fn move(destination: []u8, source: []const u8) void {
    if (@intFromPtr(destination.ptr) <= @intFromPtr(source.ptr)) {
        std.mem.copyForwards(u8, destination, source);
    } else {
        std.mem.copyBackwards(u8, destination, source);
    }
}
