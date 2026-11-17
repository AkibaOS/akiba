//! Kata Descriptor Ownership State

const std = @import("std");

const completion = @import("mirai").kata.completion;
const constants = @import("mirai").kata.constants.pool;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const lifecycle = @import("mirai").kata.lifecycle;
const types = @import("mirai").kata.types;

const Kagami = kagami.types.kagami.Kagami;
const Kata = types.kata.Kata;
const ReleaseObserver = types.callbacks.ReleaseObserver;

var kernel_kata: Kata = undefined;
var initialized: bool = false;
var descriptors: [constants.MAX_KATAS]Kata = undefined;
var occupied: [constants.MAX_KATAS]bool = [_]bool{false} ** constants.MAX_KATAS;
var next_id: u64 = constants.KERNEL_ID + 1;
var release_observer: ?ReleaseObserver = null;

pub fn setReleaseObserver(handler: ReleaseObserver) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (release_observer != null) return false;
    release_observer = handler;
    return true;
}

pub fn notifyRelease(owner: *Kata) void {
    if (release_observer) |handler| handler(owner);
}

pub fn findByID(id: u64) ?*Kata {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    for (occupied, 0..) |used, index| {
        if (!used) continue;
        const owner = &descriptors[index];
        if (owner.Permanent or owner.ID != id) continue;
        return owner;
    }
    return null;
}

pub fn initializeKernel() bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (initialized) return false;
    const root = kagami.state.getKernelKagami();
    if (!kagami.state.hasOwnedKernel() or kagami.state.getCurrentKagami() != root or
        !kagami.activate.isActive(root) or !kagami.retain.acquire(root)) return false;
    kernel_kata = .{ .ID = constants.KERNEL_ID, .AddressSpace = root, .Permanent = true };
    initialized = true;
    return true;
}

pub fn getKernel() ?*Kata {
    return if (initialized) &kernel_kata else null;
}

pub fn canReserve() bool {
    if (!initialized or next_id == std.math.maxInt(u64) or !completion.storage.hasCapacity()) return false;
    for (occupied) |used| {
        if (!used) return true;
    }
    return false;
}

pub fn reserve(root: *Kagami, launcher_id: u64) ?*Kata {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!initialized or next_id == std.math.maxInt(u64) or
        !kagami.create.owns(root) or root.ExecutionOwners != 1) return null;
    for (&occupied, 0..) |*used, index| {
        if (used.*) continue;
        if (!completion.storage.reserve(next_id, launcher_id)) return null;
        descriptors[index] = .{ .ID = next_id, .AddressSpace = root };
        next_id += 1;
        used.* = true;
        return &descriptors[index];
    }
    return null;
}

fn poolIndex(owner: *const Kata) ?usize {
    const address = @intFromPtr(owner);
    const start = @intFromPtr(&descriptors);
    if (address < start) return null;
    const offset = address - start;
    if (offset % @sizeOf(Kata) != 0) return null;
    const index = offset / @sizeOf(Kata);
    return if (index < descriptors.len) index else null;
}

pub fn owns(owner: *const Kata) bool {
    if (initialized and owner == &kernel_kata) return true;
    const index = poolIndex(owner) orelse return false;
    return occupied[index];
}

pub fn release(owner: *Kata) bool {
    const index = poolIndex(owner) orelse return false;
    if (!occupied[index] or owner.Permanent or owner.ThreadCount != 0 or owner.LiveThreadCount != 0 or
        owner.RunnableThreadCount != 0 or (owner.State != .Born and owner.State != .Dead) or
        owner.AddressSpace.PML4Physical != 0) return false;
    if (!completion.lifetime.release(owner.ID)) return false;
    lifecycle.discard(owner);
    occupied[index] = false;
    return true;
}
