//! Run queue management

const types = @import("../types.zig");

var head: ?*types.Kata = null;

pub fn get_head() ?*types.Kata {
    return head;
}

pub fn enqueue(kata: *types.Kata) void {
    kata.state = .Alive;

    if (head == null) {
        head = kata;
        kata.next = null;
        return;
    }

    var prev: ?*types.Kata = null;
    var current = head;

    while (current) |curr| {
        if (kata.vruntime < curr.vruntime) {
            kata.next = curr;
            if (prev) |p| {
                p.next = kata;
            } else {
                head = kata;
            }
            return;
        }
        prev = curr;
        current = curr.next;
    }

    if (prev) |p| {
        p.next = kata;
        kata.next = null;
    }
}

pub fn dequeue(kata: *types.Kata) void {
    if (head == null) return;

    if (head == kata) {
        head = kata.next;
        kata.next = null;
        return;
    }

    var prev = head;
    while (prev) |p| {
        if (p.next == kata) {
            p.next = kata.next;
            kata.next = null;
            return;
        }
        prev = p.next;
    }
}

pub fn is_queued(kata: *types.Kata) bool {
    var current = head;
    while (current) |k| {
        if (k == kata) return true;
        current = k.next;
    }
    return false;
}
