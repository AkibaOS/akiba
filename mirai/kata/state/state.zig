//! Kata Descriptor Ownership State

const std = @import("std");

const completion = @import("mirai").kata.completion;
const constants = @import("mirai").kata.constants.pool;
const fields = @import("mirai").kata.strings.fields;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const labels = @import("mirai").kata.strings.pool;
const lifecycle = @import("mirai").kata.lifecycle;
const memory = @import("mirai").memory;
const messages = @import("mirai").kata.strings.messages;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").kata.types;

const Kagami = kagami.types.kagami.Kagami;
const Kata = types.kata.Kata;
const ReleaseObserver = types.callbacks.ReleaseObserver;
const Slot = types.slot.Slot;
const SlotStore = memory.types.pool.store.create(Slot);
const Tree = tree.types.index.Tree;

var kernel_slot: Slot = undefined;
var initialized: bool = false;
var records: SlotStore = .{};
var identities: Tree = .{};
var next_id: u64 = constants.KERNEL_ID + 1;
var release_observer: ?ReleaseObserver = null;

pub fn setReleaseObserver(handler: ReleaseObserver) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (release_observer != null) return false;
    release_observer = handler;
    return true;
}

pub fn notifyRelease(owner: *Kata) void {
    if (release_observer) |handler| handler(owner);
}

pub fn findByID(id: u64) ?*Kata {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (id == constants.KERNEL_ID) return null;
    const node = tree.lookup.find(&identities, id) orelse return null;
    const slot: *Slot = @fieldParentPtr(fields.KATA_INDEX, node);
    return &slot.Descriptor;
}

pub fn initializeKernel() bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (initialized) return false;
    const root = kagami.state.getKernelKagami();
    if (!kagami.state.hasOwnedKernel() or kagami.state.getCurrentKagami() != root or
        !kagami.activate.isActive(root) or !kagami.retain.acquire(root)) return false;
    kernel_slot = .{ .Descriptor = .{ .ID = constants.KERNEL_ID, .AddressSpace = root, .Permanent = true } };
    initialized = true;
    return true;
}

pub fn getKernel() ?*Kata {
    return if (initialized) &kernel_slot.Descriptor else null;
}

pub fn canReserve() bool {
    return initialized and next_id != std.math.maxInt(u64) and completion.storage.hasCapacity() and
        records.LastGeneration != std.math.maxInt(u64) and records.Count != std.math.maxInt(usize);
}

pub fn reserve(root: *Kagami, launcher_id: u64) ?*Kata {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!initialized or next_id == std.math.maxInt(u64) or !kagami.create.owns(root) or root.ExecutionOwners != 1) return null;
    if (records.Zone == null) records.init(labels.KATA) catch return null;
    const slot = records.reserve() catch return null;
    const id = next_id;
    slot.* = .{ .Descriptor = .{ .ID = id, .AddressSpace = root } };
    if (!completion.storage.reserve(id, launcher_id)) {
        discard(slot);
        return null;
    }
    if (!tree.insert.insert(&identities, &slot.Index, id)) {
        if (!completion.lifetime.release(id)) @panic(messages.INVALID_CLEANUP);
        discard(slot);
        return null;
    }
    next_id += 1;
    return &slot.Descriptor;
}

pub fn data(owner: *const Kata) ?*Slot {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (initialized and owner == &kernel_slot.Descriptor) return &kernel_slot;
    const address = @intFromPtr(owner);
    const offset = @offsetOf(Slot, fields.KATA_DESCRIPTOR);
    if (address < offset) return null;
    const slot_address = address - offset;
    if (slot_address == 0 or slot_address % @alignOf(Slot) != 0) return null;
    const slot: *Slot = @ptrFromInt(slot_address);
    return if (records.owns(slot)) slot else null;
}

pub fn owns(owner: *const Kata) bool {
    return data(owner) != null;
}

pub fn first() ?*Kata {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = records.first() orelse return null;
    return &slot.Descriptor;
}

pub fn next(owner: *const Kata) ?*Kata {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = data(owner) orelse return null;
    if (slot == &kernel_slot) return first();
    const following = records.next(slot) orelse return null;
    return &following.Descriptor;
}

pub fn release(owner: *Kata) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = data(owner) orelse return false;
    if (owner.Permanent or owner.ThreadCount != 0 or owner.LiveThreadCount != 0 or owner.RunnableThreadCount != 0 or
        (owner.State != .Born and owner.State != .Dead) or owner.AddressSpace != null or slot.Threads != null or slot.Pages != null or
        tree.lookup.find(&identities, owner.ID) != &slot.Index) return false;
    if (!completion.lifetime.release(owner.ID)) return false;
    lifecycle.discard(owner);
    if (!tree.remove.remove(&identities, &slot.Index)) @panic(messages.INVALID_CLEANUP);
    discard(slot);
    return true;
}

fn discard(slot: *Slot) void {
    if (!records.release(slot)) @panic(messages.INVALID_CLEANUP);
    _ = records.collectAt(slot);
}
