//! Off CPU Scheduler Record Retirement

const control = @import("asm").cpu.constants.control;
const cpu = @import("asm").cpu.state;
const messages = @import("mirai").sensei.strings.messages;
const queue = @import("mirai").sensei.queue;
const registry = @import("mirai").sensei.registry;
const state = @import("mirai").sensei.state;
const thread = @import("mirai").thread;

pub fn collect() void {
    const scheduler = state.getState();
    if (!scheduler.Initialized or (cpu.readFlags() & control.RFLAGS_INTERRUPT_ENABLE) != 0 or
        scheduler.IRQDepth != 0 or scheduler.PreemptionDepth != 0) @panic(messages.INVALID_STATE);
    const current = thread.state.getCurrent() orelse @panic(messages.INVALID_STATE);
    const idle = scheduler.Idle orelse @panic(messages.INVALID_STATE);
    if (!thread.state.owns(current) or !current.Managed or current.Status != .Running or registry.current() == null)
        @panic(messages.INVALID_STATE);
    while (queue.take(&scheduler.Retired)) |record| {
        const target = record.Thread orelse @panic(messages.INVALID_STATE);
        if (record == idle or target == current or !thread.state.owns(target) or target.Permanent or
            !target.Managed or target.Status != .Stopped or registry.find(target) != record)
            @panic(messages.INVALID_STATE);
        thread.state.notifyInactive(target);
        target.Managed = false;
        if (!registry.release(record)) @panic(messages.INVALID_STATE);
    }
}
