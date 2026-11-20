//! Accounted Thread Admission And State Changes

const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const messages = @import("mirai").thread.strings.shift.messages;
const state = @import("mirai").thread.state;
const types = @import("mirai").thread.types;

const State = types.state.lifecycle.State;
const Thread = types.thread.Thread;

pub fn admit(target: *Thread) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.owns(target) or target.Admitted or target.Status != .Ready or
        !kata.lifecycle.admit(target.Owner)) return false;
    target.Admitted = true;
    return true;
}

pub fn change(target: *Thread, next: State) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.owns(target) or !kata.state.owns(target.Owner)) @panic(messages.INVALID_CONTEXT);
    if (target.Admitted) {
        kata.lifecycle.change(target.Owner, target.Status, next);
    } else if (next != .Stopped or target.Status != .Ready) {
        @panic(messages.INVALID_CONTEXT);
    }
    target.Status = next;
}
