//! Sensei - The Kata scheduler using CFS-lite algorithm
//! Sensei (先生) = Teacher/master who guides all Kata

const kata_mod = @import("kata.zig");
const idt = @import("../interrupts/idt.zig");
const serial = @import("../drivers/serial.zig");
const shift = @import("shift.zig");

const Kata = kata_mod.Kata;

// Sorted run queue (by vruntime)
var run_queue_head: ?*Kata = null;
var current_kata: ?*Kata = null;

// Minimum vruntime in system (for new Kata fairness)
var min_vruntime: u64 = 0;

// Timer tick counter
var tick_count: u64 = 0;

const TICK_NANOSECONDS: u64 = 1_000_000; // 1ms per tick

pub fn init() void {
    serial.print("\n=== Sensei Scheduler ===\n");
    serial.print("CFS-lite algorithm initialized\n");
    serial.print("Tick interval: 1ms\n");
}

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

// Pick next Kata to run (lowest vruntime)
pub fn pick_next_kata() ?*Kata {
    return run_queue_head;
}

// Called on timer tick
pub fn on_tick() void {
    tick_count += 1;

    if (current_kata) |kata| {
        // Update vruntime for running kata
        const delta = (TICK_NANOSECONDS * 1024) / kata.weight;
        kata.vruntime += delta;

        // Update min_vruntime
        if (run_queue_head) |head| {
            min_vruntime = head.vruntime;
        } else {
            min_vruntime = kata.vruntime;
        }

        // Check if we should shift (every 10ms)
        if (tick_count % 10 == 0) {
            schedule();
        }
    } else {
        // No kata running - check if there's one waiting
        if (run_queue_head != null) {
            schedule();
        }
    }
}

// Main scheduling decision
pub fn schedule() void {
    const next = pick_next_kata();

    if (next == null and current_kata == null) {
        // Nothing to run
        return;
    }

    // If same Kata, keep running
    if (next == current_kata) {
        return;
    }

    // Save current Kata and shift to next
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

        // Perform context shift
        shift.shift_to_kata(n);
    }
}

pub fn get_current_kata() ?*Kata {
    return current_kata;
}

pub fn clear_current_kata() void {
    current_kata = null;
}
