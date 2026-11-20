//! Scheduler Queue Population Width Regression

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.sensei;
const labels = @import("tests").guest.strings.sensei;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const verify = @import("tests").guest.support.verify;

const Queue = sensei.types.queue.links.Queue;
const Record = sensei.types.record.Record;
const Store = memory.types.pool.store.create(Record);

var records: Store = .{};
var queue: Queue = .{};

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    try records.init(labels.WIDTH_NAME);
    _ = memory.zone.gc.collect(memory.zone.bootstrap.getPageMetaZone());
    const before = pmm.state.getStatistics();
    defer {
        budget.clear();
        while (sensei.queue.take(&queue)) |record| _ = records.release(record);
        while (records.first()) |record| {
            if (!records.release(record)) break;
        }
        _ = records.collect();
        _ = records.deinit();
        _ = memory.zone.gc.collect(memory.zone.bootstrap.getPageMetaZone());
    }
    const current = thread.state.getCurrent().?;
    var middle: ?*Record = null;
    for (0..inputs.QUEUE_POPULATION_COUNT) |index| {
        const record = try records.reserve();
        record.* = .{ .Thread = current };
        if (!sensei.queue.append(&queue, record)) verify.require(false, labels.WIDTH_GROWTH);
        if (index == inputs.QUEUE_POPULATION_COUNT / 2) middle = record;
    }
    const grew = queue.Count == inputs.QUEUE_POPULATION_COUNT and records.Count == inputs.QUEUE_POPULATION_COUNT;
    verify.require(grew, labels.WIDTH_GROWTH);
    const extra = try records.reserve();
    extra.* = .{ .Thread = current };
    const count = queue.Count;
    const head = queue.Head;
    const tail = queue.Tail;
    queue.Count = std.math.maxInt(usize);
    const refused = !sensei.queue.append(&queue, extra);
    queue.Count = count;
    const unchanged = queue.Head == head and queue.Tail == tail and extra.Queue == null and extra.Next == null and extra.Previous == null;
    const removed = sensei.queue.remove(&queue, middle.?);
    const unlinked = middle.?.Queue == null and middle.?.Next == null and middle.?.Previous == null;
    const released_middle = records.release(middle.?);
    const released_extra = records.release(extra);
    verify.require(grew and refused and unchanged and removed and unlinked and released_middle and released_extra and
        queue.Count == inputs.QUEUE_POPULATION_COUNT - 1, labels.WIDTH_REMOVE);
    budget.arm(0);
    var drained: usize = 0;
    var valid = true;
    while (sensei.queue.take(&queue)) |record| {
        valid = valid and record.Queue == null and record.Next == null and record.Previous == null;
        const released = records.release(record);
        valid = valid and released;
        drained += 1;
    }
    _ = records.collect();
    _ = memory.zone.gc.collect(memory.zone.bootstrap.getPageMetaZone());
    budget.clear();
    verify.require(valid and drained == inputs.QUEUE_POPULATION_COUNT - 1 and queue.Count == 0 and queue.Head == null and
        queue.Tail == null and records.Count == 0 and std.meta.eql(before, pmm.state.getStatistics()), labels.WIDTH_RELEASE);
}
