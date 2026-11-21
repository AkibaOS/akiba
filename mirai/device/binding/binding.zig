//! Bind Installed Device Roles To Live Owned Katas

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;

const Kata = kata.types.kata.Kata;
const Role = @import("shared").launch.types.device.Role;

var bindings: [std.enums.values(Role).len]?u64 = @splat(null);

pub fn assign(launcher: u64, identifier: u64, role: Role) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const child = kata.state.findByID(identifier) orelse return error.InvalidTarget;
    if (identifier == launcher or child.Permanent or child.CanProvision or !active(child)) return error.InvalidTarget;
    if (kata.completion.storage.ownerOf(identifier) != launcher) return error.NotOwner;
    if (owner(role) != null) return error.AlreadyBound;
    for (bindings) |bound| if (bound == identifier) return error.AlreadyBound;
    bindings[@intFromEnum(role)] = identifier;
}

pub fn owner(role: Role) ?*Kata {
    const flags = guard.acquire();
    defer guard.release(flags);
    const identifier = bindings[@intFromEnum(role)] orelse return null;
    const child = kata.state.findByID(identifier) orelse return null;
    return if (active(child)) child else null;
}

fn active(child: *const Kata) bool {
    return child.State == .Alive or child.State == .Sleeping;
}
