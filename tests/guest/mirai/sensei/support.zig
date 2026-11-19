//! Bounded Scheduler Fixture Lifetime

const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.sensei;
const limits = @import("tests").constants.guest;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const verify = @import("tests").guest.support.verify;

pub fn drain(owner_id: u64) !void {
    var attempts: usize = 0;
    while (attempts < limits.DRIVE_LIMIT) : (attempts += 1) {
        try sensei.run.yield();
        const flags = guard.acquire();
        const runnable = sensei.state.getState().Ready.Count != 0;
        guard.release(flags);
        if (!runnable) return;
    }
    try dispose(owner_id);
    verify.require(false, labels.DRIVE_LIMIT);
}

pub fn dispose(owner_id: u64) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    sensei.retire.collect();
    if (kata.state.findByID(owner_id)) |owner| {
        switch (owner.State) {
            .Born => {
                var current = thread.state.firstFor(owner);
                while (current) |target| {
                    current = thread.state.nextFor(target);
                    try thread.destroy.destroy(target);
                }
                try kata.destroy.destroy(owner);
            },
            .Alive, .Sleeping => try kata.finish.terminate(owner, .Completed),
            .Dead => kata.collect.collect(),
        }
    }
    if (kata.state.findByID(owner_id) != null) @panic(labels.CLEANUP_FAILED);
    if (kata.completion.storage.ownerOf(owner_id) != null) _ = try kata.completion.lifetime.collect(owner_id);
}
