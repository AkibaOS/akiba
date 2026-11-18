//! Pre Activation Owned Root Allocation Rollback Checks

const std = @import("std");

const allocation = @import("tests").guest.support.allocation;
const common = @import("common");
const cpu = @import("asm").cpu;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.tables;
const memory = @import("mirai").boot.sequence.memory;
const pmm = @import("mirai").pmm;
const retirement = @import("mirai").boot.retirement;
const types = @import("mirai").boot.types;
const zones = @import("mirai").memory.zone.bootstrap;

const BootInfo = types.sequence.info.BootInfo;
const Range = pmm.types.storage.Range;
const sizes = common.constants.memory.sizes;

var completed: bool = false;
var retirement_checked: bool = false;

pub fn checkZoneRollback() void {
    defer allocation.clear();
    const before = pmm.state.getStatistics();
    const search_start = pmm.state.getState().SearchStart;
    for (0..2) |budget| {
        allocation.arm(budget);
        if (zones.init()) |_| {
            @panic(labels.ZONE_SEED_ROLLBACK);
        } else |failure| {
            if (failure != error.OutOfMemory or zones.isInitialized() or
                !std.meta.eql(before, pmm.state.getStatistics()) or search_start != pmm.state.getState().SearchStart)
                @panic(labels.ZONE_SEED_ROLLBACK);
        }
    }
}

pub fn run(info: *const BootInfo) void {
    defer allocation.clear();
    completed = false;
    mustRefuseRetirement(info);
    const warm = kagami.bootstrap.prepare(info) catch @panic(labels.EARLY_FAILURE);
    allocation.arm(0);
    kagami.bootstrap.abort(warm);
    allocation.clear();
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const previous = cpu.control.readCR3();
    var failures: usize = 0;
    while (true) : (failures += 1) {
        allocation.arm(failures);
        if (kagami.bootstrap.prepare(info)) |prepared| {
            allocation.arm(0);
            const valid = prepared.TableCount == prepared.Kagami.TablePages and
                prepared.TableCount != 0 and prepared.StackCount != 0 and kagami.tables.ownership.reset(&prepared.Kagami);
            kagami.bootstrap.abort(prepared);
            allocation.clear();
            if (!valid or failures <= 2 or prepared.Phase != .Empty or prepared.TableCount != 0 or prepared.StackCount != 0 or
                prepared.Kagami.Frames != null or prepared.Kagami.TablePages != 0 or
                previous != cpu.control.readCR3() or search != pmm.state.getState().SearchStart or
                !std.meta.eql(before, pmm.state.getStatistics())) @panic(labels.EARLY_FAILURE);
            completed = true;
            return;
        } else |failure| {
            allocation.clear();
            if (failure != error.OutOfMemory or previous != cpu.control.readCR3() or search != pmm.state.getState().SearchStart or
                !std.meta.eql(before, pmm.state.getStatistics())) @panic(labels.EARLY_FAILURE);
        }
    }
}

pub fn retire(info: *const BootInfo) ?u64 {
    defer allocation.clear();
    allocation.arm(0);
    const owned = info.Retirement orelse @panic(labels.RETIREMENT_FAILURE);
    const node = @constCast(retirement.layout.ledger(owned.Tables.LedgerPhysical));
    if (owned.Tables.ChildFrames < 2 or !allReserved(info)) @panic(labels.RETIREMENT_FAILURE);
    const second = if (node.Count > 1) &node.Frames[1] else &@constCast(retirement.layout.ledger(node.NextPhysical)).Frames[0];
    const frame = second.*;
    second.* = node.Frames[0];
    mustRefuseRetirement(info);
    second.* = frame;
    if (!allReserved(info)) @panic(labels.RETIREMENT_FAILURE);

    node.MapPages += 1;
    mustRefuseRetirement(info);
    node.MapPages -= 1;
    refuseDisconnectedGraph(info);

    var overlapping = info.*;
    overlapping.Retirement.?.Parameters = owned.Map;
    mustRefuseRetirement(&overlapping);
    var foreign = info.*;
    const image = info.KernelPhysicalBase / sizes.PAGE_SIZE;
    foreign.Retirement.?.Parameters = .{ .Start = image, .End = image + 1 };
    mustRefuseRetirement(&foreign);
    if (!allReserved(info)) @panic(labels.RETIREMENT_FAILURE);

    const keep = retirement.layout.retainedWindows(info);
    var expected: u64 = 0;
    for (owned.fixed()) |range| expected += eligibleCount(range, keep);
    var physical = owned.Tables.LedgerPhysical;
    while (physical != 0) {
        const chunk = retirement.layout.ledger(physical);
        expected += eligibleCount(single(physical), keep);
        for (chunk.Frames[0..chunk.Count]) |child| expected += eligibleCount(single(child), keep);
        physical = chunk.NextPhysical;
    }
    const before = pmm.state.getStatistics();
    const pages = memory.retireLoader(info) orelse return null;
    const after = pmm.state.getStatistics();
    if (pages != expected or after.FreePages != before.FreePages + pages or
        after.ReservedPages + pages != before.ReservedPages or after.UsedPages != before.UsedPages or
        after.TotalPages != before.TotalPages or after.MetadataPages != before.MetadataPages or
        after.MetadataBytes != before.MetadataBytes or !expectedRoles(single(frame), keep) or
        !expectedRoles(single(owned.Tables.LedgerPhysical), keep) or !pmm.state.isAllocated(info.PML4Physical) or
        pmm.state.getRole(info.KernelPhysicalBase) == .Free) @panic(labels.RETIREMENT_FAILURE);
    for (owned.fixed()) |range| {
        if (!expectedRoles(range, keep)) @panic(labels.RETIREMENT_FAILURE);
    }
    mustRefuseRetirement(info);
    allocation.clear();
    checkAllocatorReuse(info.LoaderPML4Physical, keep);
    retirement_checked = true;
    return pages;
}

fn checkAllocatorReuse(physical: u64, keep: [2]Range) void {
    const page = physical / sizes.PAGE_SIZE;
    if (!eligible(page, keep)) return;
    const manager = pmm.state.getState();
    const search = manager.SearchStart;
    defer manager.SearchStart = search;
    const before = pmm.state.getStatistics();
    manager.SearchStart = page;
    const reused = pmm.allocate.single.allocatePage() catch @panic(labels.RETIREMENT_FAILURE);
    if (reused != physical or !pmm.state.isAllocated(reused) or !pmm.free.single.releasePage(reused) or
        !std.meta.eql(before, pmm.state.getStatistics())) @panic(labels.RETIREMENT_FAILURE);
}

fn refuseDisconnectedGraph(info: *const BootInfo) void {
    const address = common.constants.memory.layout.PHYSMAP_BASE + info.LoaderPML4Physical;
    const entries: *[sizes.ENTRIES_PER_PAGE_TABLE]u64 = @ptrFromInt(address);
    for (entries) |*entry| {
        if (entry.* & common.constants.paging.flags.PRESENT == 0) continue;
        const original = entry.*;
        entry.* = 0;
        defer entry.* = original;
        mustRefuseRetirement(info);
        return;
    }
    @panic(labels.RETIREMENT_FAILURE);
}

fn single(physical: u64) Range {
    const page = physical / sizes.PAGE_SIZE;
    return .{ .Start = page, .End = page + 1 };
}

fn eligible(page: u64, keep: [2]Range) bool {
    for (keep) |window| {
        if (page >= window.Start and page < window.End) return false;
    }
    return true;
}

fn eligibleCount(range: Range, keep: [2]Range) u64 {
    var count: u64 = 0;
    for (range.Start..range.End) |page| count += @intFromBool(eligible(page, keep));
    return count;
}

fn expectedRoles(range: Range, keep: [2]Range) bool {
    for (range.Start..range.End) |page| {
        const role: pmm.types.storage.Role = if (eligible(page, keep)) .Free else .Reserved;
        if (pmm.state.getRole(page * sizes.PAGE_SIZE) != role) return false;
    }
    return true;
}

fn allReserved(info: *const BootInfo) bool {
    const owned = info.Retirement orelse return false;
    const index = pmm.state.getState().Index;
    for (owned.fixed()) |range| {
        if (!pmm.storage.access.matches(index, range.Start, range.End, .Reserved)) return false;
    }
    var physical = owned.Tables.LedgerPhysical;
    while (physical != 0) {
        if (pmm.state.getRole(physical) != .Reserved) return false;
        const node = retirement.layout.ledger(physical);
        for (node.Frames[0..node.Count]) |frame| {
            if (pmm.state.getRole(frame) != .Reserved) return false;
        }
        physical = node.NextPhysical;
    }
    return true;
}

fn mustRefuseRetirement(info: *const BootInfo) void {
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    if (memory.retireLoader(info) != null or search != pmm.state.getState().SearchStart or
        !std.meta.eql(before, pmm.state.getStatistics())) @panic(labels.RETIREMENT_FAILURE);
}

pub fn passed() bool {
    return completed;
}

pub fn retirementPassed() bool {
    return retirement_checked;
}
