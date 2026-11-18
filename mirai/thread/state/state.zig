//! Thread Descriptor And Active Execution State

const fields = @import("mirai").thread.strings.fields;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const labels = @import("mirai").thread.strings.pool;
const memory = @import("mirai").memory;
const messages = @import("mirai").thread.strings.shift.messages;
const types = @import("mirai").thread.types;

const InactiveObserver = types.callbacks.InactiveObserver;
const Kata = kata.types.kata.Kata;
const KernelStack = memory.types.stack.kernel.KernelStack;
const SchedulerRecord = @import("mirai").sensei.types.record.Record;
const Slot = types.slot.Slot;
const SlotStore = memory.types.pool.store.create(Slot);
const SwitchHandler = types.callbacks.SwitchHandler;
const Thread = types.thread.Thread;

var boot_slot: Slot = undefined;
var boot_initialized: bool = false;
var current_thread: ?*Thread = null;
var records: SlotStore = .{};
var inactive_observer: ?InactiveObserver = null;
var switch_handler: ?SwitchHandler = null;

pub fn setInactiveObserver(handler: InactiveObserver) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (inactive_observer != null) return false;
    inactive_observer = handler;
    return true;
}

pub fn notifyInactive(target: *Thread) void {
    kata.wait.cancel(target);
    if (inactive_observer) |handler| handler(target);
}

pub fn hasLive(owner: *const Kata, excluding: *const Thread) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    var current = firstFor(owner);
    while (current) |target| {
        if (target != excluding and target.Status != .Stopped) return true;
        current = nextFor(target);
    }
    return false;
}

pub fn setSwitchHandler(handler: SwitchHandler) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (switch_handler != null) return false;
    switch_handler = handler;
    return true;
}

pub fn completeSwitch() void {
    if (switch_handler) |handler| handler();
}

pub fn initializeBoot(owner: *Kata, stack: KernelStack) bool {
    if (boot_initialized or current_thread != null or owner != kata.state.getKernel() or
        !owner.Permanent or owner.ThreadCount != 0) return false;
    const root = owner.AddressSpace orelse return false;
    const owned = kata.state.data(owner) orelse return false;
    if (owned.Threads != null) return false;
    boot_slot = .{
        .Descriptor = .{
            .Owner = owner,
            .Stack = stack,
            .Context = .{ .CR3 = root.PML4Physical },
            .Status = .Running,
            .Started = true,
            .Admitted = true,
            .Permanent = true,
        },
    };
    owner.ThreadCount = 1;
    if (!kata.lifecycle.admit(owner)) return false;
    owned.Threads = &boot_slot.Descriptor;
    current_thread = &boot_slot.Descriptor;
    boot_initialized = true;
    return true;
}

pub fn getCurrent() ?*Thread {
    return current_thread;
}

fn slotAt(address: usize) ?*Slot {
    if (address == 0 or address % @alignOf(Slot) != 0) return null;
    const slot: *Slot = @ptrFromInt(address);
    return if (records.owns(slot)) slot else null;
}

pub fn data(target: *const Thread) ?*Slot {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (boot_initialized and target == &boot_slot.Descriptor) return &boot_slot;
    const address = @intFromPtr(target);
    const offset = @offsetOf(Slot, fields.DESCRIPTOR);
    return if (address < offset) null else slotAt(address - offset);
}

pub fn fromScheduler(record: *const SchedulerRecord) ?*Thread {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (boot_initialized and record == &boot_slot.Scheduler) return &boot_slot.Descriptor;
    const address = @intFromPtr(record);
    const offset = @offsetOf(Slot, fields.SCHEDULER);
    if (address < offset) return null;
    const slot = slotAt(address - offset) orelse return null;
    return &slot.Descriptor;
}

pub fn owns(target: *const Thread) bool {
    return data(target) != null;
}

pub fn first() ?*Thread {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = records.first() orelse return null;
    return &slot.Descriptor;
}

pub fn next(target: *const Thread) ?*Thread {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = data(target) orelse return null;
    if (slot == &boot_slot) return first();
    const following = records.next(slot) orelse return null;
    return &following.Descriptor;
}

pub fn firstFor(owner: *const Kata) ?*Thread {
    const flags = guard.acquire();
    defer guard.release(flags);
    const owned = kata.state.data(owner) orelse return null;
    return owned.Threads;
}

pub fn nextFor(target: *const Thread) ?*Thread {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = data(target) orelse return null;
    return slot.OwnerNext;
}

pub fn generation(target: *const Thread) ?u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = data(target) orelse return null;
    if (slot == &boot_slot) return null;
    return records.generation(slot);
}

pub fn reserve(owner: *Kata) ?*Thread {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!boot_initialized or !kata.state.owns(owner) or owner.State == .Dead or owner.AddressSpace == null) return null;
    const owned = kata.state.data(owner) orelse return null;
    const slot = records.reserveNamed(labels.DESCRIPTORS) catch return null;
    slot.* = .{ .Descriptor = .{ .Owner = owner, .Stack = .{ .Base = 0, .Top = 0 } }, .OwnerNext = owned.Threads };
    if (owned.Threads) |first_thread| {
        const first_slot = data(first_thread) orelse @panic(messages.INVALID_CONTEXT);
        first_slot.OwnerPrevious = &slot.Descriptor;
    }
    owned.Threads = &slot.Descriptor;
    return &slot.Descriptor;
}

pub fn release(target: *Thread) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = data(target) orelse return false;
    if (target == current_thread or target.Permanent or target.Managed or
        (target.Status != .Ready and target.Status != .Stopped) or (target.Admitted and target.Status != .Stopped) or
        slot.Scheduler.Thread != null or slot.Observer.Thread != null or slot.Postman.Thread != null) return false;
    const owned = kata.state.data(target.Owner) orelse return false;
    if (slot.OwnerPrevious) |previous| {
        const previous_slot = data(previous) orelse return false;
        if (previous_slot.OwnerNext != target) return false;
        previous_slot.OwnerNext = slot.OwnerNext;
    } else {
        if (owned.Threads != target) return false;
        owned.Threads = slot.OwnerNext;
    }
    if (slot.OwnerNext) |following| {
        const following_slot = data(following) orelse @panic(messages.INVALID_CONTEXT);
        following_slot.OwnerPrevious = slot.OwnerPrevious;
    }
    if (!records.release(slot)) @panic(messages.INVALID_CONTEXT);
    _ = records.collectAt(slot);
    records.pruneEmpty();
    return true;
}

pub fn setCurrent(target: *Thread) bool {
    if (!owns(target) or target.Status != .Running) return false;
    current_thread = target;
    return true;
}
