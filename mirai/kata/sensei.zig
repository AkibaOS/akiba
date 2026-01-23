//! Sensei - The Kata scheduler using CFS-lite algorithm
//! Sensei (先生) = Teacher/master who guides all Kata

const kata_mod = @import("kata.zig");
const idt = @import("../interrupts/idt.zig");
const serial = @import("../drivers/serial.zig");
const shift = @import("shift.zig");
const keyboard = @import("../drivers/keyboard.zig");

const Kata = kata_mod.Kata;

// Sorted run queue (by vruntime)
var run_queue_head: ?*Kata = null;
var current_kata: ?*Kata = null;

// Minimum vruntime in system (for new Kata fairness)
var min_vruntime: u64 = 0;

// Timer tick counter
var tick_count: u64 = 0;

const TICK_NANOSECONDS: u64 = 1_000_000; // 1ms per tick

pub fn init() void {}

// Add Kata to run queue (sorted by vruntime)
pub fn enqueue_kata(new_kata: *Kata) void {
    new_kata.state = .Ready;

    // If queue is empty
    if (run_queue_head == null) {
        run_queue_head = new_kata;
        new_kata.next = null;
        return;
    }

    // Insert sorted by vruntime (lowest first)
    var prev: ?*Kata = null;
    var current = run_queue_head;

    while (current) |curr| {
        if (new_kata.vruntime < curr.vruntime) {
            // Insert before current
            new_kata.next = curr;
            if (prev) |p| {
                p.next = new_kata;
            } else {
                run_queue_head = new_kata;
            }
            return;
        }
        prev = curr;
        current = curr.next;
    }

    // Insert at end
    if (prev) |p| {
        p.next = new_kata;
        new_kata.next = null;
    }
}

// Remove Kata from run queue
pub fn dequeue_kata(target_kata: *Kata) void {
    if (run_queue_head == null) return;

    // Check head
    if (run_queue_head == target_kata) {
        run_queue_head = target_kata.next;
        target_kata.next = null;
        return;
    }

    // Search list
    var prev = run_queue_head;
    while (prev) |p| {
        if (p.next == target_kata) {
            p.next = target_kata.next;
            target_kata.next = null;
            return;
        }
        prev = p.next;
    }
}

// Check if a kata is already in the run queue
pub fn is_in_queue(target_kata: *Kata) bool {
    var current = run_queue_head;
    while (current) |kata| {
        if (kata == target_kata) return true;
        current = kata.next;
    }
    return false;
}

// Pick next Kata to run (lowest vruntime)
fn pick_next_kata() ?*Kata {
    var current = run_queue_head;
    var local_min_vruntime: u64 = 0xFFFFFFFFFFFFFFFF;
    var chosen: ?*Kata = null;
    var fallback: ?*Kata = null;

    while (current) |kata| {
        if (kata.state == .Ready and kata.vruntime < local_min_vruntime) {
            local_min_vruntime = kata.vruntime;
            chosen = kata;
        }
        if (kata.state == .Running) {
            fallback = kata;
        }
        current = kata.next;
    }

    if (chosen) |k| {
        return k;
    }

    // If no Ready kata, check if current_kata should keep running
    if (current_kata) |curr| {
        if (curr.state == .Running) {
            return curr;
        }
    }

    // Also check fallback from queue
    if (fallback) |k| {
        return k;
    }

    return null;
}

// Called on timer tick
pub fn on_tick() void {
    tick_count += 1;

    // // Wake blocked katas if keyboard has input
    // if (tick_count % 5 == 0) { // Check every 5ms
    //     wake_blocked_katas();
    // }

    if (current_kata) |kata| {
        const delta = (TICK_NANOSECONDS * 1024) / kata.weight;
        kata.vruntime += delta;

        if (run_queue_head) |head| {
            min_vruntime = head.vruntime;
        } else {
            min_vruntime = kata.vruntime;
        }

        // // ONLY schedule if there are other katas waiting
        // if (run_queue_head != null and tick_count % 10 == 0) {
        //     schedule();
        // }
    }
}

// Main scheduling decision
pub fn schedule() void {
    wake_all_waiting_katas();

    const next = pick_next_kata();

    if (next == null and current_kata == null) {
        while (true) {
            asm volatile ("hlt");
        }
    }

    // If same kata is picked, we still need to dequeue it and set to Running
    if (next == current_kata and next != null) {
        // Same kata picked - dequeue it since it was enqueued by yield
        dequeue_kata(next.?);
        next.?.state = .Running;
        // No shift needed - just return
        return;
    }

    if (current_kata) |curr| {
        if (curr.state == .Running) {
            curr.state = .Ready;
            enqueue_kata(curr);
        }
    }

    if (next) |n| {
        dequeue_kata(n);
        n.state = .Running;
        current_kata = n;
        shift.shift_to_kata(n);
        unreachable;
    }

    clear_current_kata();
    while (true) {
        asm volatile ("hlt");
    }
}

fn wake_all_waiting_katas() void {
    var i: usize = 0;
    while (i < kata_mod.MAX_KATA) : (i += 1) {
        if (!kata_mod.kata_used[i]) continue;

        const kata = &kata_mod.kata_pool[i];
        if (kata.state != .Waiting) continue;

        // Check if the Kata we're waiting for has exited
        const target = kata_mod.get_kata(kata.waiting_for);
        if (target == null or target.?.state == .Dissolved) {
            // Target exited, wake this Kata up
            kata.state = .Ready;
            enqueue_kata(kata);
            kata.waiting_for = 0;
        }
    }
}

// Wake katas waiting for a specific kata (called when a kata dissolves)
pub fn wake_waiting_katas(target_id: u32) void {
    var i: usize = 0;
    while (i < kata_mod.MAX_KATA) : (i += 1) {
        if (!kata_mod.kata_used[i]) continue;

        const kata = &kata_mod.kata_pool[i];
        if (kata.state == .Waiting and kata.waiting_for == target_id) {
            kata.state = .Ready;
            enqueue_kata(kata);
            kata.waiting_for = 0;
        }
    }
}

// Wake katas blocked on keyboard input
fn wake_blocked_katas() void {
    // Only wake if keyboard has input
    if (!keyboard.has_input()) return;

    // Wake only ONE blocked kata per character (FIFO order)
    var i: usize = 0;
    while (i < kata_mod.MAX_KATA) : (i += 1) {
        if (!kata_mod.kata_used[i]) continue;

        const kata = &kata_mod.kata_pool[i];
        if (kata.state == .Blocked) {
            kata.state = .Ready;
            enqueue_kata(kata);
            // Only wake one kata at a time for keyboard input
            return;
        }
    }
}

// Wake one blocked kata (called from keyboard interrupt)
pub fn wake_one_blocked_kata() void {
    var i: usize = 0;
    while (i < kata_mod.MAX_KATA) : (i += 1) {
        if (!kata_mod.kata_used[i]) continue;

        const kata = &kata_mod.kata_pool[i];
        if (kata.state == .Blocked) {
            kata.state = .Ready;
            enqueue_kata(kata);
            return;
        }
    }
}

// Wake a specific kata by ID (called from interrupt handlers)
pub fn wake_kata(kata_id: u32) void {
    const kata = kata_mod.get_kata(kata_id) orelse return;

    if (kata.state == .Blocked) {
        kata.state = .Ready;
        enqueue_kata(kata);
    }
}

pub fn get_current_kata() ?*Kata {
    return current_kata;
}

pub fn clear_current_kata() void {
    current_kata = null;
}
