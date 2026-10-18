//! Kagami Execution Ownership

const std = @import("std");

const create = @import("mirai").kagami.create;
const guard = @import("asm").interrupts.guard;
const state = @import("mirai").kagami.state;
const types = @import("mirai").kagami.types;

const Kagami = types.kagami.Kagami;

pub fn acquire(kagami: *Kagami) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!(state.hasOwnedKernel() and kagami.isKernel()) and !create.owns(kagami)) return false;
    if (kagami.ExecutionOwners == std.math.maxInt(u64)) return false;
    kagami.ExecutionOwners += 1;
    return true;
}

pub fn release(kagami: *Kagami) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!(state.hasOwnedKernel() and kagami.isKernel()) and !create.owns(kagami)) return false;
    if (kagami.ExecutionOwners == 0) return false;
    kagami.ExecutionOwners -= 1;
    return true;
}
