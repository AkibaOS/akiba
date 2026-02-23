//! Sensei - Kata scheduler

const cpu = @import("../../asm/cpu.zig");
const pool = @import("../pool.zig");
const queue = @import("queue.zig");
const shift = @import("../shift.zig");
const types = @import("../types.zig");
const waker = @import("waker.zig");

var current: ?*types.Kata = null;
var min_vruntime: u64 = 0;
var tick_count: u64 = 0;

const TICK_NS: u64 = 1_000_000;

pub fn on_tick() void {
    tick_count += 1;
}

pub fn get_tick_count() u64 {
    return tick_count;
}

pub fn schedule() void {
    waker.wake_all_waiting();

    if (current) |kata| {
        const elapsed = tick_count - kata.last_run;
        if (elapsed > 0) {
            const delta = (TICK_NS * 1024 * elapsed) / kata.weight;
            kata.vruntime += delta;
            kata.last_run = tick_count;
        }
    }

    const next = pick_next();

    if (next == null and current == null) {
        halt_loop();
    }

    if (next == current and next != null) {
        queue.dequeue(next.?);
        next.?.state = .Flowing;
        return;
    }

    if (current) |curr| {
        if (curr.state == .Flowing) {
            curr.state = .Alive;
            queue.enqueue(curr);
        }
    }

    if (next) |n| {
        queue.dequeue(n);
        n.state = .Flowing;
        n.last_run = tick_count;
        current = n;
        shift.to_kata(n);
        unreachable;
    }

    clear_current();
    halt_loop();
}

pub fn enqueue_kata(kata: *types.Kata) void {
    queue.enqueue(kata);
}

pub fn dequeue_kata(kata: *types.Kata) void {
    queue.dequeue(kata);
}

pub fn is_in_queue(kata: *types.Kata) bool {
    return queue.is_queued(kata);
}

pub fn get_current_kata() ?*types.Kata {
    return current;
}

pub fn clear_current_kata() void {
    current = null;
}

pub fn wake_waiting_katas(target_id: u32) void {
    waker.wake_waiting(target_id);
}

pub fn wake_one_blocked_kata() void {
    waker.wake_one_blocked();
}

pub fn wake_kata(kata_id: u32) void {
    waker.wake(kata_id);
}

fn pick_next() ?*types.Kata {
    var curr = queue.get_head();
    var local_min: u64 = 0xFFFFFFFFFFFFFFFF;
    var chosen: ?*types.Kata = null;
    var fallback: ?*types.Kata = null;

    while (curr) |kata| {
        if (kata.state == .Alive and kata.vruntime < local_min) {
            local_min = kata.vruntime;
            chosen = kata;
        }
        if (kata.state == .Flowing) {
            fallback = kata;
        }
        curr = kata.next;
    }

    if (chosen) |k| {
        min_vruntime = k.vruntime;
        return k;
    }

    if (current) |c| {
        if (c.state == .Flowing) return c;
    }

    if (fallback) |k| return k;

    return null;
}

fn clear_current() void {
    current = null;
}

fn halt_loop() noreturn {
    while (true) {
        cpu.halt_processor();
    }
}
