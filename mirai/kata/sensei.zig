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
fn pick_next_kata() ?*Kata {
    serial.print("pick_next_kata called, checking queue...\n");
    serial.print("  run_queue_head: ");
    serial.print_hex(@intFromPtr(run_queue_head));
    serial.print("\n");

    // Debug: show all katas
    var i: usize = 0;
    while (i < kata_mod.MAX_KATA) : (i += 1) {
        if (kata_mod.kata_used[i]) {
            serial.print("  Kata ");
            serial.print_hex(kata_mod.kata_pool[i].id);
            serial.print(" state: ");
            serial.print_hex(@intFromEnum(kata_mod.kata_pool[i].state));
            serial.print(", next: ");
            serial.print_hex(@intFromPtr(kata_mod.kata_pool[i].next));
            serial.print("\n");
        }
    }

    var current = run_queue_head;
    var local_min_vruntime: u64 = 0xFFFFFFFFFFFFFFFF;
    var chosen: ?*Kata = null;
    var fallback: ?*Kata = null;

    serial.print("  Traversing queue:\n");
    while (current) |kata| {
        serial.print("    Checking Kata ");
        serial.print_hex(kata.id);
        serial.print(", state ");
        serial.print_hex(@intFromEnum(kata.state));
        serial.print("\n");

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
        serial.print("  Chose Ready kata: ");
        serial.print_hex(k.id);
        serial.print("\n");
        return k;
    }

    // NEW: If no Ready kata, check if current_kata should keep running
    if (current_kata) |curr| {
        if (curr.state == .Running) {
            serial.print("  No Ready kata, continuing current: ");
            serial.print_hex(curr.id);
            serial.print("\n");
            return curr;
        }
    }

    // Also check fallback from queue
    if (fallback) |k| {
        serial.print("  Chose Running kata (fallback): ");
        serial.print_hex(k.id);
        serial.print("\n");
        return k;
    }

    serial.print("  No kata available!\n");
    return null;
}

// Called on timer tick
pub fn on_tick() void {
    tick_count += 1;

    if (current_kata) |kata| {
        const delta = (TICK_NANOSECONDS * 1024) / kata.weight;
        kata.vruntime += delta;

        if (run_queue_head) |head| {
            min_vruntime = head.vruntime;
        } else {
            min_vruntime = kata.vruntime;
        }

        // ONLY schedule if there are other katas waiting
        if (run_queue_head != null and tick_count % 10 == 0) {
            schedule();
        }
    }
}

// Main scheduling decision
pub fn schedule() void {
    const rbp = asm volatile ("mov %%rbp, %[ret]"
        : [ret] "=r" (-> u64),
    );
    serial.print("\n=== Sensei Schedule (called from RBP: ");
    serial.print_hex(rbp);
    serial.print(") ===\n");
    serial.print("\n=== Sensei Schedule ===\n");
    wake_waiting_katas();

    const next = pick_next_kata();

    if (next == null and current_kata == null) {
        serial.print("Sensei: No katas to run\n");
        while (true) {
            asm volatile ("hlt");
        }
    }

    // DON'T return early - always handle the shift properly
    if (next == current_kata and next != null) {
        // Same kata, but we might be coming from interrupt
        // Just continue - no shift needed
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

    serial.print("Sensei: No more katas after dissolution\n");
    clear_current_kata();
    while (true) {
        asm volatile ("hlt");
    }
}

fn wake_waiting_katas() void {
    var i: usize = 0;
    while (i < kata_mod.MAX_KATA) : (i += 1) {
        if (!kata_mod.kata_used[i]) continue;

        const kata = &kata_mod.kata_pool[i];
        if (kata.state != .Waiting) continue;

        // Check if the Kata we're waiting for has exited
        const target = kata_mod.get_kata(kata.waiting_for);
        if (target == null or target.?.state == .Dissolved) {
            // Target exited, wake this Kata up
            serial.print("Sensei: Waking Kata ");
            serial.print_hex(kata.id);
            serial.print(" (target ");
            serial.print_hex(kata.waiting_for);
            serial.print(" dissolved)\n");

            kata.state = .Ready;
            enqueue_kata(kata);
            kata.waiting_for = 0;
        }
    }
}

pub fn get_current_kata() ?*Kata {
    return current_kata;
}

pub fn clear_current_kata() void {
    current_kata = null;
}
