//! Validated Physmap User Transfers

const std = @import("std");

const access = @import("mirai").user.state.access;
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
const UserError = usererrors.UserError;

pub fn read(owner: *const Kata, destination: []u8, user_address: u64) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const plan = try prepare(owner, user_address, destination.len, false, false);
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
    return writeOwned(owner, user_address, source, false);
}

pub fn load(owner: *const Kata, user_address: u64, source: []const u8) UserError!void {
    return writeOwned(owner, user_address, source, true);
}

pub fn validate(owner: *const Kata, address: u64, length: usize, write_access: bool) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    _ = prepare(owner, address, length, write_access, false) catch return false;
    return true;
}

fn writeOwned(owner: *const Kata, user_address: u64, source: []const u8, loading_only: bool) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const plan = try prepare(owner, user_address, source.len, true, loading_only);
    var snapshot: [limits.MAX_COPY_BYTES]u8 = undefined;
    move(snapshot[0..source.len], source);
    var offset: usize = 0;
    for (plan.Segments[0..plan.Count]) |segment| {
        const destination: [*]u8 = @ptrFromInt(segment.Alias);
        @memcpy(destination[0..segment.Length], snapshot[offset..][0..segment.Length]);
        offset += segment.Length;
    }
}

fn prepare(owner: *const Kata, address: u64, length: usize, write_access: bool, loading_only: bool) UserError!Plan {
    if (length > limits.MAX_COPY_BYTES) return UserError.CopyTooLarge;
    if (!checks.isValidOwner(owner) or (write_access and owner.State == .Dead)) return UserError.InvalidOwner;
    if (!checks.isValidRange(address, length)) return UserError.InvalidUserRange;
    var plan = Plan{};
    if (length == 0) return plan;
    var current_address = address;
    var remaining = length;
    while (remaining != 0) {
        if (plan.Count == plan.Segments.len) return UserError.CopyTooLarge;
        const record = ledger.find(owner, current_address & ~sizes.PAGE_MASK) orelse return UserError.NotOwned;
        if (loading_only and record.Stage != .Loading) return UserError.SealedPage;
        try access.validate(record, write_access);
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

fn move(destination: []u8, source: []const u8) void {
    if (@intFromPtr(destination.ptr) <= @intFromPtr(source.ptr)) {
        std.mem.copyForwards(u8, destination, source);
    } else {
        std.mem.copyBackwards(u8, destination, source);
    }
}
