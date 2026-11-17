//! Off CPU Dead Kata Resource Collection

const completion = @import("mirai").kata.completion;
const destroy = @import("mirai").kata.destroy;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const messages = @import("mirai").kata.strings.messages;
const pool = @import("mirai").thread.constants.pool;
const state = @import("mirai").kata.state;
const thread = @import("mirai").thread;
const types = @import("mirai").kata.types;

const Kata = types.kata.Kata;

fn quiescent(owner: *const Kata) bool {
    const root = owner.AddressSpace orelse return false;
    if (owner.LiveThreadCount != 0 or owner.RunnableThreadCount != 0 or
        root == kagami.state.getCurrentKagami() or kagami.activate.isActive(root)) return false;
    var slot: usize = 0;
    while (slot < pool.MAX_THREADS) : (slot += 1) {
        const target = thread.state.at(slot) orelse continue;
        if (target.Owner != owner) continue;
        if (target == thread.state.getCurrent() or target.Managed or target.Status != .Stopped) return false;
    }
    return true;
}

pub fn collect() void {
    const flags = guard.acquire();
    defer guard.release(flags);
    var current = completion.pending.first();
    while (current) |record| {
        current = completion.pending.next(record);
        const owner = state.findByID(record.ID) orelse @panic(messages.INVALID_CLEANUP);
        if (owner.State != .Dead or owner.Permanent) @panic(messages.INVALID_CLEANUP);
        if (!quiescent(owner)) continue;
        var slot: usize = 0;
        while (slot < pool.MAX_THREADS) : (slot += 1) {
            const target = thread.state.at(slot) orelse continue;
            if (target.Owner != owner) continue;
            thread.destroy.destroy(target) catch @panic(messages.INVALID_CLEANUP);
        }
        destroy.destroy(owner) catch @panic(messages.INVALID_CLEANUP);
    }
}
