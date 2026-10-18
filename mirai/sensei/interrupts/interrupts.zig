//! Outermost Acknowledged IRQ Scheduling

const std = @import("std");

const messages = @import("mirai").sensei.strings.messages;
const run = @import("mirai").sensei.run;
const state = @import("mirai").sensei.state;

pub fn enter() void {
    const scheduler = state.getState();
    if (!scheduler.Initialized) return;
    if (scheduler.IRQDepth == std.math.maxInt(u32)) @panic(messages.INVALID_STATE);
    scheduler.IRQDepth += 1;
}

pub fn leave() void {
    const scheduler = state.getState();
    if (!scheduler.Initialized) return;
    if (scheduler.IRQDepth == 0) @panic(messages.INVALID_STATE);
    scheduler.IRQDepth -= 1;
    if (scheduler.IRQDepth != 0 or !scheduler.Pending) return;
    if (scheduler.PreemptionDepth != 0) {
        scheduler.Deferred +%= 1;
        return;
    }
    run.reschedule(false);
}
