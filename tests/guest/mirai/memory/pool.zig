//! Stable Typed Storage Lifetime Regressions

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.pool;
const labels = @import("tests").guest.strings.pool;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const types = @import("tests").guest.types.pool;
const verify = @import("tests").guest.support.verify;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const Value = types.Value;
const Store = memory.types.pool.store.create(Value);
const PageStore = memory.types.pool.store.create(types.Page);
const OversizedStore = memory.types.pool.store.create(types.Oversized);
const OveralignedStore = memory.types.pool.store.create(types.Overaligned);

var values: Store = .{};
var pages: PageStore = .{};
var terminal: Store = .{};
var allocations = [_]?*Value{null} ** inputs.LIVE_COUNT;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    try growth();
    try membership();
    try lifetimes();
    try failure();
    try coldFailure();
    try exhausted();
    geometry();
}

fn coldFailure() !void {
    const zone = memory.zone.bootstrap.getZoneZone();
    var held: [sizes.PAGE_SIZE / @sizeOf(memory.types.zone.Zone)]*memory.types.zone.Zone = undefined;
    var count: usize = 0;
    defer for (held[0..count]) |descriptor| {
        verify.require(memory.zone.destroy.destroy(descriptor), labels.ZONE_LIFETIME);
    };
    while (zone.PartialPages != null and count < held.len) {
        held[count] = try memory.zone.create.create(labels.NAME, @sizeOf(Value));
        count += 1;
    }
    verify.require(zone.PartialPages == null, labels.COLD_ROLLBACK);

    const before = pmm.state.getStatistics();
    const search_start = pmm.state.getState().SearchStart;
    var candidate: Store = .{};
    var attempts: usize = 0;
    while (true) : (attempts += 1) {
        budget.arm(attempts);
        if (candidate.reserveNamed(labels.NAME)) |value| {
            budget.clear();
            verify.require(attempts >= 2 and candidate.release(value), labels.COLD_ROLLBACK);
            candidate.pruneEmpty();
            break;
        } else |reason| {
            budget.clear();
            verify.require(reason == error.OutOfMemory and candidate.Zone == null and candidate.Count == 0 and
                search_start == pmm.state.getState().SearchStart and std.meta.eql(before, pmm.state.getStatistics()), labels.COLD_ROLLBACK);
        }
    }
    verify.require(candidate.Zone == null and std.meta.eql(before, pmm.state.getStatistics()), labels.COLD_ROLLBACK);
}

fn growth() !void {
    try values.init(labels.NAME);
    defer cleanup(&values);
    var previous: u64 = 0;
    var retained = true;
    for (&allocations, 0..) |*allocation, index| {
        const value = try values.reserve();
        allocation.* = value;
        stamp(value, index);
        const generation = values.generation(value).?;
        retained = retained and generation > previous and @intFromPtr(value) % inputs.VALUE_ALIGNMENT == 0;
        previous = generation;
        if (index == inputs.LIVE_COUNT / 2) try values.init(labels.NAME);
    }
    for (allocations, 0..) |allocation, index| retained = retained and values.owns(allocation.?) and matches(allocation.?, index);
    verify.require(retained and values.Count == inputs.LIVE_COUNT, labels.GROWTH);
    var current = values.first();
    var visited: usize = 0;
    while (current) |value| {
        verify.require(visited < inputs.LIVE_COUNT, labels.ITERATION);
        const next = values.next(value);
        retained = retained and value == allocations[visited] and matches(value, visited);
        if (visited % 2 == 0) {
            const released = values.release(value);
            retained = retained and released;
            allocations[visited] = null;
        }
        visited += 1;
        current = next;
    }
    verify.require(retained and visited == inputs.LIVE_COUNT and values.Count == inputs.LIVE_COUNT / 2, labels.ITERATION);
    while (values.first()) |value| {
        const index = value.Index;
        const intact = matches(value, index);
        const released = values.release(value);
        verify.require(released, labels.ITERATION);
        retained = retained and intact;
        allocations[index] = null;
    }
    verify.require(retained and values.Count == 0 and values.collect() != 0 and values.deinit(), labels.REINITIALIZED);
}

fn membership() !void {
    try values.init(labels.NAME);
    defer cleanup(&values);
    const original = try values.reserve();
    const neighbor = try values.reserve();
    stamp(original, 0);
    stamp(neighbor, 1);
    const generation = values.generation(original).?;
    const interior: *Value = @ptrFromInt(@intFromPtr(original) + inputs.INTERIOR_OFFSET);
    var foreign: Value = .{ .Bytes = undefined, .Index = 0 };
    verify.require(!values.release(interior) and !values.owns(interior) and values.generation(interior) == null and
        !values.release(&foreign) and !values.owns(&foreign) and values.Count == 2 and
        matches(original, 0) and matches(neighbor, 1), labels.MEMBERSHIP);
    var copied = values;
    var refused = false;
    copied.init(labels.NAME) catch |reason| {
        refused = reason == error.InvalidSize;
    };
    var rejected = false;
    if (copied.reserve()) |_| {
        rejected = false;
    } else |reason| {
        rejected = reason == error.NotInitialized;
    }
    verify.require(refused and rejected and !copied.owns(original) and !copied.release(original) and
        copied.collect() == 0 and !copied.deinit() and values.Count == 2 and
        values.generation(original).? == generation and matches(original, 0), labels.COPIED);
    verify.require(!values.deinit() and values.owns(original) and values.owns(neighbor), labels.LIVE_RELEASE);
    const released = values.release(original);
    verify.require(released and !values.release(original) and !values.owns(original) and values.generation(original) == null and
        values.owns(neighbor) and matches(neighbor, 1) and values.Count == 1, labels.MEMBERSHIP);
}

fn lifetimes() !void {
    const search = pmm.state.getState().SearchStart;
    defer {
        cleanup(&pages);
        pmm.state.getState().SearchStart = search;
    }
    try pages.init(labels.PAGE_NAME);
    const original = try pages.reserve();
    stamp(original, 0);
    const generation = pages.generation(original).?;
    const physical_page = ((@intFromPtr(original) & ~sizes.PAGE_MASK) - layout.PHYSMAP_BASE) / sizes.PAGE_SIZE;
    const released = pages.release(original);
    const reused = try pages.reserve();
    stamp(reused, 1);
    const reused_generation = pages.generation(reused).?;
    verify.require(released and reused == original and reused_generation > generation and matches(reused, 1), labels.LIFETIME);
    const released_again = pages.release(reused);
    const before_collection = pmm.state.getStatistics();
    const collected = pages.collectAt(reused);
    const after_collection = pmm.state.getStatistics();
    const reclaimed = collected != 0 and after_collection.FreePages == before_collection.FreePages + collected and pages.collect() == 0;
    verify.require(released_again and reclaimed, labels.TARGETED);
    _ = memory.zone.gc.collect(memory.zone.bootstrap.getPageMetaZone());
    pmm.state.getState().SearchStart = physical_page;
    const rebuilt = try pages.reserve();
    stamp(rebuilt, 2);
    const rebuilt_generation = pages.generation(rebuilt).?;
    verify.require(rebuilt == original and rebuilt_generation > reused_generation and
        matches(rebuilt, 2), labels.LIFETIME);
    const released_rebuilt = pages.release(rebuilt);
    const deinitialized = pages.deinit();
    try pages.init(labels.PAGE_NAME);
    pmm.state.getState().SearchStart = physical_page;
    const renewed = try pages.reserve();
    stamp(renewed, 3);
    verify.require(released_rebuilt and deinitialized and renewed == original and pages.generation(renewed).? > rebuilt_generation and
        matches(renewed, 3), labels.REINITIALIZED);
}

fn failure() !void {
    try pages.init(labels.PAGE_NAME);
    defer cleanup(&pages);
    const original = try pages.reserve();
    stamp(original, 0);
    const generation = pages.generation(original).?;
    const before = pmm.state.getStatistics();
    var refused = false;
    budget.arm(0);
    if (pages.reserve()) |unexpected| {
        budget.clear();
        _ = pages.release(unexpected);
    } else |reason| {
        budget.clear();
        refused = reason == error.OutOfMemory;
    }
    verify.require(refused and pages.Count == 1 and pages.owns(original) and pages.generation(original).? == generation and
        matches(original, 0) and std.meta.eql(before, pmm.state.getStatistics()), labels.FAILURE);
    const recovered = try pages.reserve();
    stamp(recovered, 1);
    budget.arm(0);
    const released_original = pages.release(original);
    const targeted = pages.collectAt(original);
    const preserved = pages.owns(recovered) and matches(recovered, 1) and pages.collectAt(recovered) == 0;
    const released_recovered = pages.release(recovered);
    const collected = pages.collect();
    const deinitialized = pages.deinit();
    budget.clear();
    verify.require(released_original and targeted != 0 and preserved and released_recovered and collected != 0 and deinitialized, labels.RECOVERY);
}

fn exhausted() !void {
    try terminal.init(labels.TERMINAL_NAME);
    defer cleanup(&terminal);
    terminal.LastGeneration = std.math.maxInt(u64) - 1;
    const last = try terminal.reserve();
    const witness = terminal.generation(last).?;
    var refused = false;
    if (terminal.reserve()) |unexpected| {
        _ = terminal.release(unexpected);
    } else |reason| {
        refused = reason == error.RegionExhausted;
    }
    const released = terminal.release(last);
    const deinitialized = terminal.deinit();
    try terminal.init(labels.TERMINAL_NAME);
    var retired = false;
    if (terminal.reserve()) |unexpected| {
        _ = terminal.release(unexpected);
    } else |reason| {
        retired = reason == error.RegionExhausted;
    }
    verify.require(witness == std.math.maxInt(u64) and refused and released and deinitialized and retired and
        terminal.LastGeneration == std.math.maxInt(u64), labels.EXHAUSTED);
}

fn geometry() void {
    var oversized: OversizedStore = .{};
    var overaligned: OveralignedStore = .{};
    const before = pmm.state.getStatistics();
    var too_large = false;
    oversized.init(labels.INVALID_NAME) catch |reason| {
        too_large = reason == error.SizeTooLarge;
    };
    var alignment = false;
    overaligned.init(labels.INVALID_NAME) catch |reason| {
        alignment = reason == error.InvalidAlignment;
    };
    verify.require(too_large and alignment and std.meta.eql(before, pmm.state.getStatistics()), labels.INVALID);
    const unknown: *memory.types.zone.Zone = @ptrFromInt(sizes.PAGE_SIZE);
    verify.require(!memory.zone.destroy.destroy(memory.zone.bootstrap.getZoneZone()) and
        !memory.zone.destroy.destroy(memory.zone.bootstrap.getPageMetaZone()) and !memory.zone.destroy.destroy(unknown), labels.ZONE_LIFETIME);
}

fn stamp(value: anytype, index: usize) void {
    value.* = .{ .Bytes = undefined, .Index = index };
    @memset(value.Bytes[0..], @intCast(index % std.math.maxInt(u8) + 1));
}

fn matches(value: anytype, index: usize) bool {
    return value.Index == index and std.mem.allEqual(u8, value.Bytes[0..], @intCast(index % std.math.maxInt(u8) + 1));
}

fn cleanup(store: anytype) void {
    budget.clear();
    while (store.first()) |value| {
        if (!store.release(value)) break;
    }
    _ = store.collect();
    _ = store.deinit();
    _ = memory.zone.gc.collect(memory.zone.bootstrap.getPageMetaZone());
}
