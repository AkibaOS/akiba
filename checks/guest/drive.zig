//! Bounded Guest Scheduling

const guard = @import("asm").interrupts.guard;
const labels = @import("checks").strings.guest;
const limits = @import("checks").constants.guest;
const sensei = @import("mirai").sensei;

pub fn run() void {
    var attempts: usize = 0;
    while (attempts < limits.DRIVE_LIMIT) : (attempts += 1) {
        sensei.run.yield() catch @panic(labels.INVALID_STATE);
        const flags = guard.acquire();
        const runnable = sensei.state.getState().Ready.Count != 0;
        guard.release(flags);
        if (!runnable) return;
    }
    @panic(labels.INVALID_STATE);
}
