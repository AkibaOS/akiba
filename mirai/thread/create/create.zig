//! Guarded Kernel Thread Construction

const std = @import("std");

const common = @import("common");
const cpu = @import("asm").cpu;
const entry = @import("mirai").thread.entry;
const errors = @import("mirai").thread.errors.ownership;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const stack = @import("mirai").memory.stack;
const state = @import("mirai").thread.state;
const types = @import("mirai").thread.types;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Entry = types.entry.Entry;
const Kata = kata.types.kata.Kata;
const MappingError = common.errors.memory.mapping.MappingError;
const OwnershipError = errors.OwnershipError;
const Thread = types.thread.Thread;

pub fn create(owner: *Kata, start: Entry, argument: ?*anyopaque) (AllocationError || MappingError || OwnershipError)!*Thread {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (state.getCurrent() == null) return OwnershipError.NotInitialized;
    if (!kata.state.owns(owner)) return OwnershipError.InvalidOwner;
    if (owner.ThreadCount == std.math.maxInt(u64) or owner.AddressSpace.ExecutionOwners == 0 or
        !kagami.activate.canActivate(owner.AddressSpace)) return OwnershipError.InvalidState;
    const thread = state.reserve(owner) orelse return AllocationError.OutOfMemory;
    errdefer _ = state.release(thread);
    const kernel_stack = try stack.allocate.allocate();
    errdefer stack.free.free(kernel_stack);
    if (!stack.state.retain(kernel_stack.Base)) return OwnershipError.InvalidState;
    const pointer: *u64 = @ptrFromInt(kernel_stack.Top - @sizeOf(u64));
    pointer.* = 0;
    thread.* = .{
        .Owner = owner,
        .Stack = kernel_stack,
        .Context = .{
            .RDI = @intFromPtr(thread),
            .RSP = kernel_stack.Top - @sizeOf(u64),
            .RIP = @intFromPtr(&entry.start),
            .CR3 = owner.AddressSpace.PML4Physical,
            .FPU = cpu.constants.fpu.INITIAL_STATE,
        },
        .EntryPoint = start,
        .Argument = argument,
        .EnableInterrupts = (previous_flags & cpu.constants.control.RFLAGS_INTERRUPT_ENABLE) != 0,
    };
    owner.ThreadCount += 1;
    return thread;
}
