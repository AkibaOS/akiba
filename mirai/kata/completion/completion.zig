//! Reserved And Retained Kata Outcomes

const constants = @import("mirai").kata.constants.pool;
const guard = @import("asm").interrupts.guard;
const types = @import("mirai").kata.types;

const Completion = types.completion.Completion;
const Outcome = types.outcome.Outcome;

var records: [constants.MAX_KATAS]Completion = [_]Completion{.{}} ** constants.MAX_KATAS;

pub fn hasCapacity() bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    for (records) |record| {
        if (record.ID == constants.KERNEL_ID) return true;
    }
    return false;
}

fn find(id: u64) ?*Completion {
    if (id == constants.KERNEL_ID) return null;
    for (&records) |*record| {
        if (record.ID == id) return record;
    }
    return null;
}

pub fn reserve(id: u64) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (id == constants.KERNEL_ID or find(id) != null) return false;
    for (&records) |*record| {
        if (record.ID != constants.KERNEL_ID) continue;
        record.* = .{ .ID = id };
        return true;
    }
    return false;
}

pub fn commit(id: u64, outcome: Outcome) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return false;
    if (record.Outcome != null or record.Reclaimed) return false;
    record.Outcome = outcome;
    return true;
}

pub fn release(id: u64) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return false;
    if (record.Reclaimed) return false;
    if (record.Outcome == null) record.* = .{} else record.Reclaimed = true;
    return true;
}

pub fn pending(index: usize) ?u64 {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (index >= records.len) return null;
    const record = &records[index];
    return if (record.Outcome != null and !record.Reclaimed) record.ID else null;
}

pub fn peek(id: u64) ?Outcome {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return null;
    return if (record.Reclaimed) record.Outcome else null;
}

pub fn take(id: u64) ?Outcome {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return null;
    if (!record.Reclaimed) return null;
    const outcome = record.Outcome orelse return null;
    record.* = .{};
    return outcome;
}
