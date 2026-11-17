//! Nested Scheduling Deferral Regressions

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.sensei;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.sensei;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const verify = @import("tests").verify;

fn entry(argument: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const completed: *bool = @ptrCast(@alignCast(argument.?));
    _ = guard.acquire();
    completed.* = true;
    thread.finish.complete();
}

pub fn run() !void {
    const owner = try kata.create.create();
    const owner_id = owner.ID;
    defer support.dispose(owner_id) catch |failure| verify.failure(failure);
    var completed = false;
    const target = try thread.create.create(owner, entry, &completed);
    var registered: usize = 0;
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        const scheduler = sensei.state.getState();
        registered = scheduler.RegisteredCount;
        try sensei.control.start(target);
        const current = thread.state.getCurrent();
        const switches = scheduler.Switches;
        const deferred = scheduler.Deferred;
        const depth = scheduler.PreemptionDepth;
        var levels: u32 = 0;
        defer {
            while (levels != 0) : (levels -= 1) sensei.preemption.enable();
        }
        while (levels < inputs.NESTED_DEPTH) : (levels += 1) sensei.preemption.disable();
        var rejected = false;
        sensei.run.yield() catch |failure| {
            rejected = failure == error.UnsafeContext;
        };
        verify.require(rejected and scheduler.PreemptionDepth == depth + inputs.NESTED_DEPTH and
            scheduler.Switches == switches and !completed, labels.DEFERRAL_DEPTH);
        sensei.run.reschedule(false);
        sensei.preemption.enable();
        levels -= 1;
        verify.require(scheduler.Pending and scheduler.PreemptionDepth == depth + 1 and
            scheduler.Deferred == deferred +% 1 and scheduler.Switches == switches and
            thread.state.getCurrent() == current and target.Status == .Ready and !completed, labels.DEFERRAL_INNER);
        sensei.run.reschedule(false);
        sensei.preemption.enable();
        levels -= 1;
        verify.require(scheduler.Pending and scheduler.PreemptionDepth == depth and
            scheduler.Deferred == deferred +% inputs.NESTED_DEPTH and scheduler.Switches == switches and
            thread.state.getCurrent() == current and target.Status == .Ready and !completed, labels.DEFERRAL_OUTER);
    }
    try support.drain(owner_id);
    const flags = guard.acquire();
    defer guard.release(flags);
    try support.dispose(owner_id);
    verify.require(completed and sensei.state.getState().PreemptionDepth == 0 and
        sensei.state.getState().RegisteredCount == registered and kata.state.findByID(owner_id) == null and
        kata.completion.storage.ownerOf(owner_id) == null, labels.DEFERRAL_RELEASE);
}
