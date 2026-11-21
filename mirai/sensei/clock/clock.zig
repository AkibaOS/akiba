//! Time Slice Accounting

const deadline = @import("mirai").sensei.deadline;
const registry = @import("mirai").sensei.registry;
const state = @import("mirai").sensei.state;

pub fn tick() void {
    const scheduler = state.getState();
    if (!scheduler.Initialized) return;
    scheduler.Ticks +%= 1;
    deadline.tick();
    if (registry.current() == scheduler.Idle) {
        if (scheduler.Ready.Head != null) scheduler.Pending = true;
        return;
    }
    if (scheduler.RemainingTicks != 0) scheduler.RemainingTicks -= 1;
    if (scheduler.RemainingTicks == 0) {
        if (!scheduler.Pending) scheduler.Requests +%= 1;
        scheduler.Pending = true;
    }
}
