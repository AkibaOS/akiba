//! Thread Descriptor And Active Execution State

const constants = @import("mirai").thread.constants.pool;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const types = @import("mirai").thread.types;

const InactiveObserver = types.callbacks.InactiveObserver;
const Kata = kata.types.kata.Kata;
const KernelStack = @import("mirai").memory.types.stack.kernel.KernelStack;
const SwitchHandler = types.callbacks.SwitchHandler;
const Thread = types.thread.Thread;

var boot_thread: Thread = undefined;
var boot_initialized: bool = false;
var current_thread: ?*Thread = null;
var descriptors: [constants.MAX_THREADS]Thread = undefined;
var inactive_observer: ?InactiveObserver = null;
var occupied: [constants.MAX_THREADS]bool = [_]bool{false} ** constants.MAX_THREADS;
var switch_handler: ?SwitchHandler = null;

pub fn setInactiveObserver(handler: InactiveObserver) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (inactive_observer != null) return false;
    inactive_observer = handler;
    return true;
}

pub fn notifyInactive(target: *Thread) void {
    if (inactive_observer) |handler| handler(target);
}

pub fn hasLive(owner: *const Kata, excluding: *const Thread) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (boot_initialized and &boot_thread != excluding and boot_thread.Owner == owner and
        boot_thread.Status != .Stopped) return true;
    for (occupied, 0..) |used, index| {
        if (!used) continue;
        const target = &descriptors[index];
        if (target == excluding or target.Owner != owner or target.Status == .Stopped) continue;
        return true;
    }
    return false;
}

pub fn setSwitchHandler(handler: SwitchHandler) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
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
    boot_thread = .{
        .Owner = owner,
        .Stack = stack,
        .Context = .{ .CR3 = owner.AddressSpace.PML4Physical },
        .Status = .Running,
        .Started = true,
        .Permanent = true,
    };
    owner.ThreadCount = 1;
    current_thread = &boot_thread;
    boot_initialized = true;
    return true;
}

pub fn getCurrent() ?*Thread {
    return current_thread;
}

fn poolIndex(thread: *const Thread) ?usize {
    const address = @intFromPtr(thread);
    const start = @intFromPtr(&descriptors);
    if (address < start) return null;
    const offset = address - start;
    if (offset % @sizeOf(Thread) != 0) return null;
    const index = offset / @sizeOf(Thread);
    return if (index < descriptors.len) index else null;
}

pub fn owns(thread: *const Thread) bool {
    if (boot_initialized and thread == &boot_thread) return true;
    const index = poolIndex(thread) orelse return false;
    return occupied[index];
}

pub fn reserve(owner: *Kata) ?*Thread {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!boot_initialized or !kata.state.owns(owner)) return null;
    for (&occupied, 0..) |*used, index| {
        if (used.*) continue;
        descriptors[index] = .{ .Owner = owner, .Stack = .{ .Base = 0, .Top = 0 } };
        used.* = true;
        return &descriptors[index];
    }
    return null;
}

pub fn release(thread: *Thread) bool {
    const index = poolIndex(thread) orelse return false;
    if (!occupied[index] or thread == current_thread or
        (thread.Status != .Ready and thread.Status != .Stopped) or thread.Permanent or thread.Managed) return false;
    occupied[index] = false;
    return true;
}

pub fn setCurrent(thread: *Thread) bool {
    if (!owns(thread) or thread.Status != .Running) return false;
    current_thread = thread;
    return true;
}
