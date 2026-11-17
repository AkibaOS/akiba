//! Stable Virtual Extent Partition And Failure Checks

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.range;
const labels = @import("tests").strings.range;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

const sizes = common.constants.memory.sizes;
const operations = memory.range;
const Extent = memory.types.range.extent.Extent;
const Region = memory.types.range.region.Region;

var region: Region = .{};
var retained = [_]?*Extent{null} ** inputs.RECORDS;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    try operations.lifecycle.initialize(&region, inputs.BASE, inputs.BYTES, labels.NAME);
    verify.require(operations.lifecycle.deinitialize(&region), labels.RELEASE);
    const before = pmm.state.getStatistics();
    try operations.lifecycle.initialize(&region, inputs.BASE, inputs.BYTES, labels.NAME);
    const geometry = pmm.state.getStatistics();
    const maximum = std.math.maxInt(u64) & ~sizes.PAGE_MASK;
    verify.require(reject(0, sizes.PAGE_SIZE, error.InvalidSize) and
        reject(sizes.PAGE_SIZE + 1, sizes.PAGE_SIZE, error.InvalidSize) and
        reject(sizes.PAGE_SIZE, 0, error.InvalidAlignment) and
        reject(sizes.PAGE_SIZE, sizes.PAGE_SIZE + 1, error.InvalidAlignment) and
        reject(maximum, sizes.PAGE_SIZE, error.RegionExhausted) and
        reject(sizes.PAGE_SIZE, @as(u64, 1) << (@bitSizeOf(u64) - 1), error.RegionExhausted) and
        region.Records.Count == 1 and region.ReservedBytes == 0 and std.meta.eql(geometry, pmm.state.getStatistics()), labels.GEOMETRY);
    for (&retained) |*entry| entry.* = try operations.reserve.reserve(&region, sizes.PAGE_SIZE, sizes.PAGE_SIZE);
    var stable = true;
    for (retained, 0..) |entry, index| stable = stable and entry.?.Base == inputs.BASE + index * sizes.PAGE_SIZE and
        operations.lookup.find(&region, entry.?.Base) == entry;
    verify.require(stable and region.ReservedBytes == inputs.RECORDS * sizes.PAGE_SIZE, labels.GROWTH);
    var copied = region;
    var rejected = false;
    if (operations.reserve.reserve(&copied, sizes.PAGE_SIZE, sizes.PAGE_SIZE)) |_| {
        verify.require(false, labels.COPIED);
    } else |failure| rejected = failure == error.InvalidSize;
    verify.require(rejected and operations.lookup.find(&copied, inputs.BASE) == null and
        !operations.release.release(&copied, retained[0].?), labels.COPIED);
    const live = pmm.state.getStatistics();
    const interior: *Extent = @ptrFromInt(@intFromPtr(retained[1].?) + @alignOf(Extent));
    const foreign: *Extent = @ptrFromInt(inputs.BASE);
    verify.require(!operations.release.release(&region, interior) and !operations.release.release(&region, foreign) and
        region.ReservedBytes == inputs.RECORDS * sizes.PAGE_SIZE and std.meta.eql(live, pmm.state.getStatistics()), labels.INVALID);
    budget.arm(0);
    for (&retained, 0..) |*entry, index| {
        if (index % 2 != 0) continue;
        const released = entry.*.?;
        verify.require(operations.release.release(&region, released) and !operations.release.release(&region, released), labels.INVALID);
        entry.* = null;
    }
    stable = true;
    for (retained) |entry| {
        const active = entry orelse continue;
        stable = stable and operations.lookup.find(&region, active.Base) == active;
    }
    verify.require(stable, labels.NEIGHBORS);
    for (&retained) |*entry| {
        const active = entry.* orelse continue;
        verify.require(operations.release.release(&region, active), labels.MERGE);
        entry.* = null;
    }
    verify.require(region.ReservedBytes == 0 and region.AllocatedCount == 0 and region.Records.Count == 1 and
        region.Head.?.Free and region.Head.?.Base == inputs.BASE and region.Head.?.Size == inputs.BYTES, labels.MERGE);
    verify.require(operations.lifecycle.deinitialize(&region) and std.meta.eql(before, pmm.state.getStatistics()), labels.RELEASE);
    budget.clear();
    try split();
}

fn reject(bytes: u64, alignment: u64, expected: anyerror) bool {
    if (operations.reserve.reserve(&region, bytes, alignment)) |_| return false else |failure| return failure == expected;
}

fn available() usize {
    const page = region.Records.Zone.?.PartialPages orelse return 0;
    return page.Capacity - page.InUse;
}

fn split() !void {
    const before = pmm.state.getStatistics();
    try operations.lifecycle.initialize(&region, inputs.BASE, inputs.BYTES, labels.NAME);
    var count: usize = 0;
    while (available() != 1) : (count += 1) {
        verify.require(count < retained.len, labels.SPLIT_SEED);
        retained[count] = try operations.reserve.reserve(&region, sizes.PAGE_SIZE, sizes.PAGE_SIZE);
    }
    const base = inputs.BASE + count * sizes.PAGE_SIZE;
    var alignment = 2 * sizes.PAGE_SIZE;
    while ((base & (alignment - 1)) == 0) alignment *= 2;
    const snapshot = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const records = region.Records.Count;
    const reserved = region.ReservedBytes;
    budget.arm(0);
    var rejected = false;
    if (operations.reserve.reserve(&region, sizes.PAGE_SIZE, alignment)) |_| {
        verify.require(false, labels.SPLIT_ACCEPTED);
    } else |failure| rejected = failure == error.OutOfMemory;
    budget.clear();
    verify.require(rejected, labels.SPLIT_ERROR);
    verify.require(records == region.Records.Count and region.ReservedBytes == reserved, labels.SPLIT_COUNTS);
    verify.require(search == pmm.state.getState().SearchStart, labels.SPLIT_SEARCH);
    verify.require(std.meta.eql(snapshot, pmm.state.getStatistics()), labels.SPLIT_BACKING);
    var stable = true;
    for (retained[0..count]) |entry| stable = stable and operations.lookup.find(&region, entry.?.Base) == entry;
    verify.require(stable, labels.SPLIT_FAILURE);
    const aligned = try operations.reserve.reserve(&region, sizes.PAGE_SIZE, alignment);
    verify.require(aligned.Base % alignment == 0 and aligned.Base > base and aligned.Before.?.Free and aligned.After.?.Free, labels.ALIGNMENT);
    budget.arm(0);
    verify.require(operations.release.release(&region, aligned), labels.MERGE);
    for (retained[0..count]) |*entry| {
        verify.require(operations.release.release(&region, entry.*.?), labels.MERGE);
        entry.* = null;
    }
    verify.require(operations.lifecycle.deinitialize(&region) and std.meta.eql(before, pmm.state.getStatistics()), labels.RELEASE);
    budget.clear();
}
