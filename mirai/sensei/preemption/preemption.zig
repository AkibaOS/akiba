//! Explicit Preemption Deferral

const std = @import("std");

const control = @import("asm").cpu.constants.control;
const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").sensei.strings.messages;
const run = @import("mirai").sensei.run;
const state = @import("mirai").sensei.state;

pub fn disable() void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = state.getState();
    if (!scheduler.Initialized) return;
    if (scheduler.PreemptionDepth == std.math.maxInt(u32)) @panic(messages.INVALID_STATE);
    scheduler.PreemptionDepth += 1;
}

pub fn enable() void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = state.getState();
    if (!scheduler.Initialized) return;
    if (scheduler.PreemptionDepth == 0) @panic(messages.INVALID_STATE);
    scheduler.PreemptionDepth -= 1;
    if (scheduler.PreemptionDepth == 0 and scheduler.IRQDepth == 0 and scheduler.Pending and
        (previous_flags & control.RFLAGS_INTERRUPT_ENABLE) != 0) run.reschedule(false);
}
