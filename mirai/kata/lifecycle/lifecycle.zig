//! Kata Admission Activity And Death Transitions

const completion = @import("mirai").kata.completion;
const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").kata.strings.messages;
const state = @import("mirai").kata.state;
const types = @import("mirai").kata.types;

const Kata = types.kata.Kata;
const Outcome = types.outcome.Outcome;
const ThreadState = @import("mirai").thread.types.state.State;

var pulse_id: ?u64 = null;

pub fn designatePulse(owner: *Kata) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.owns(owner) or owner.Permanent or owner.State != .Born or pulse_id != null) return false;
    pulse_id = owner.ID;
    return true;
}

pub fn discard(owner: *const Kata) void {
    if (owner.State == .Born and pulse_id == owner.ID) pulse_id = null;
}

pub fn admit(owner: *Kata) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.owns(owner) or owner.State == .Dead or owner.LiveThreadCount >= owner.ThreadCount or
        owner.RunnableThreadCount > owner.LiveThreadCount) return false;
    owner.LiveThreadCount += 1;
    owner.RunnableThreadCount += 1;
    owner.State = .Alive;
    return true;
}

fn runnable(status: ThreadState) bool {
    return status == .Ready or status == .Running;
}

pub fn change(owner: *Kata, previous: ThreadState, next: ThreadState) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.owns(owner) or owner.State == .Born or owner.LiveThreadCount > owner.ThreadCount or
        owner.RunnableThreadCount > owner.LiveThreadCount or
        (owner.State == .Dead and next != .Stopped) or previous == .Stopped) @panic(messages.INVALID_LIFECYCLE);
    if (previous == next) return;
    if (runnable(previous)) {
        if (owner.RunnableThreadCount == 0) @panic(messages.INVALID_LIFECYCLE);
        owner.RunnableThreadCount -= 1;
    }
    if (runnable(next)) owner.RunnableThreadCount += 1;
    if (next == .Stopped) {
        if (owner.LiveThreadCount == 0 or (owner.LiveThreadCount == 1 and owner.State != .Dead))
            @panic(messages.INVALID_LIFECYCLE);
        owner.LiveThreadCount -= 1;
    }
    if (owner.State != .Dead) {
        owner.State = if (owner.RunnableThreadCount == 0) .Sleeping else .Alive;
    }
    if (owner.RunnableThreadCount > owner.LiveThreadCount) @panic(messages.INVALID_LIFECYCLE);
}

pub fn die(owner: *Kata, outcome: Outcome) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.owns(owner) or owner.Permanent or owner.State == .Born or owner.State == .Dead or
        !completion.commit(owner.ID, outcome)) @panic(messages.INVALID_COMPLETION);
    owner.State = .Dead;
    if (pulse_id == owner.ID) @panic(messages.PULSE_EXIT);
}
