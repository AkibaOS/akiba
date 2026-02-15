//! Wake functions

const kata_limits = @import("../../common/limits/kata.zig");
const keyboard = @import("../../drivers/keyboard/keyboard.zig");
const pool = @import("../pool.zig");
const queue = @import("queue.zig");
const types = @import("../types.zig");

pub fn wake_all_waiting() void {
    for (0..kata_limits.MAX_KATAS) |i| {
        if (!pool.used[i]) continue;

        const kata = &pool.pool[i];
        if (kata.state != .Waiting) continue;

        const target = pool.get(kata.waiting_for);
        if (target == null or target.?.state == .Dissolved) {
            kata.state = .Ready;
            queue.enqueue(kata);
            kata.waiting_for = 0;
        }
    }
}

pub fn wake_waiting(target_id: u32) void {
    for (0..kata_limits.MAX_KATAS) |i| {
        if (!pool.used[i]) continue;

        const kata = &pool.pool[i];
        if (kata.state == .Waiting and kata.waiting_for == target_id) {
            kata.state = .Ready;
            queue.enqueue(kata);
            kata.waiting_for = 0;
        }
    }
}

pub fn wake_blocked() void {
    if (!keyboard.has_input()) return;

    for (0..kata_limits.MAX_KATAS) |i| {
        if (!pool.used[i]) continue;

        const kata = &pool.pool[i];
        if (kata.state == .Blocked) {
            kata.state = .Ready;
            queue.enqueue(kata);
            return;
        }
    }
}

pub fn wake_one_blocked() void {
    for (0..kata_limits.MAX_KATAS) |i| {
        if (!pool.used[i]) continue;

        const kata = &pool.pool[i];
        if (kata.state == .Blocked) {
            kata.state = .Ready;
            queue.enqueue(kata);
            return;
        }
    }
}

pub fn wake(kata_id: u32) void {
    const kata = pool.get(kata_id) orelse return;

    if (kata.state == .Blocked) {
        kata.state = .Ready;
        queue.enqueue(kata);
    }
}
