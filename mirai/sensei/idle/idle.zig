//! Interrupt Safe Idle Execution

const flags = @import("asm").interrupts.flags;
const halt = @import("asm").cpu.halt;
const messages = @import("mirai").sensei.strings.messages;
const registry = @import("mirai").sensei.registry;
const run = @import("mirai").sensei.run;
const state = @import("mirai").sensei.state;

pub fn runIdle() noreturn {
    while (true) {
        flags.disableInterrupts();
        const scheduler = state.getState();
        if (!scheduler.Initialized or registry.current() != scheduler.Idle or
            scheduler.PreemptionDepth != 0 or scheduler.IRQDepth != 0) @panic(messages.INVALID_STATE);
        if (scheduler.Ready.Head != null) {
            run.reschedule(false);
            continue;
        }
        scheduler.Pending = false;
        halt.waitForInterrupt();
    }
}
