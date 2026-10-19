//! Postman Lifecycle Registration

const cleanup = @import("mirai").postman.cleanup;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const state = @import("mirai").postman.state;
const thread = @import("mirai").thread;

pub fn initialize() bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const transport = state.getState();
    if (transport.Initialized) return false;
    if (!thread.state.setInactiveObserver(&cleanup.threadInactive)) return false;
    if (!kata.state.setReleaseObserver(&cleanup.kataRelease)) return false;
    transport.Initialized = true;
    return true;
}
