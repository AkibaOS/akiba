//! Allocation-Free Commit Of Verified Retired Boot Frames

const common = @import("common");
const geometry = @import("mirai").boot.retirement.layout;
const limits = @import("shared").boot.constants.retirement;
const pmm = @import("mirai").pmm;
const types = @import("mirai").boot.types;
const walk = @import("mirai").boot.retirement.walk;

const BootInfo = types.sequence.info.BootInfo;
const Footprint = types.retirement.Footprint;
const Index = pmm.types.storage.Index;
const Range = pmm.types.storage.Range;
const State = pmm.types.state.State;
const access = pmm.storage.access;
const sizes = common.constants.memory.sizes;

pub fn from(manager: *State, info: *const BootInfo) ?u64 {
    const owned = info.Retirement orelse return null;
    const index = manager.Index;
    const fixed = owned.fixed();
    if (index.PhysicalPages != info.PhysmapSize / sizes.PAGE_SIZE) return null;
    for (fixed) |range| {
        if (range.Start >= range.End or range.End > index.PhysicalPages or
            !access.matches(index, range.Start, range.End, .Reserved)) return null;
    }
    if (!geometry.validate(info, index)) return null;
    const ledger_pages = owned.Tables.ChildFrames / limits.LEDGER_CAPACITY +
        @intFromBool(owned.Tables.ChildFrames % limits.LEDGER_CAPACITY != 0);
    var pages = ledger_pages + owned.Tables.ChildFrames;
    for (fixed) |range| pages += range.End - range.Start;
    if (pages > manager.Statistics.ReservedPages) return null;

    var committed = false;
    defer if (!committed) restoreMarks(index, owned);
    for (fixed) |range| {
        if (!mark(index, range)) return null;
    }
    var remaining = owned.Tables.ChildFrames;
    var physical = owned.Tables.LedgerPhysical;
    while (remaining != 0) {
        if (!mark(index, single(physical))) return null;
        const node = geometry.ledger(physical);
        for (node.Frames[0..node.Count]) |frame| {
            if (!mark(index, single(frame))) return null;
        }
        remaining -= node.Count;
        physical = node.NextPhysical;
    }

    for (fixed[1..]) |range| unmark(index, range);
    remaining = owned.Tables.ChildFrames;
    physical = owned.Tables.LedgerPhysical;
    while (remaining != 0) {
        const node = geometry.ledger(physical);
        unmark(index, single(physical));
        remaining -= node.Count;
        physical = node.NextPhysical;
    }
    if (!walk.exact(owned, info.PhysmapSize, index, consumeTableMark)) return null;

    committed = true;
    const keep = geometry.retainedWindows(info);
    var released: u64 = 0;
    remaining = owned.Tables.ChildFrames;
    physical = owned.Tables.LedgerPhysical;
    while (remaining != 0) {
        const node = geometry.ledger(physical);
        const next = node.NextPhysical;
        for (node.Frames[0..node.Count]) |frame| released += publish(manager, single(frame), keep);
        remaining -= node.Count;
        released += publish(manager, single(physical), keep);
        physical = next;
    }
    for (fixed) |range| released += publish(manager, range, keep);
    return released;
}

fn single(physical: u64) Range {
    const page = physical / sizes.PAGE_SIZE;
    return .{ .Start = page, .End = page + 1 };
}

fn mark(index: Index, range: Range) bool {
    if (!access.matches(index, range.Start, range.End, .Reserved)) return false;
    access.assign(index, range, .Retiring);
    return true;
}

fn unmark(index: Index, range: Range) void {
    if (access.matches(index, range.Start, range.End, .Retiring)) access.assign(index, range, .Reserved);
}

fn consumeTableMark(index: Index, page: u64) bool {
    if (access.read(index, page) != .Retiring) return false;
    access.assign(index, .{ .Start = page, .End = page + 1 }, .Reserved);
    return true;
}

fn restoreMarks(index: Index, owned: Footprint) void {
    for (owned.fixed()) |range| unmark(index, range);
    var remaining = owned.Tables.ChildFrames;
    var physical = owned.Tables.LedgerPhysical;
    while (remaining != 0) {
        const node = geometry.ledger(physical);
        for (node.Frames[0..node.Count]) |frame| unmark(index, single(frame));
        unmark(index, single(physical));
        remaining -= node.Count;
        physical = node.NextPhysical;
    }
}

fn publish(manager: *State, range: Range, keep: [2]Range) u64 {
    var released: u64 = 0;
    var start = range.Start;
    while (start < range.End) {
        var skip = start;
        var end = range.End;
        for (keep) |window| {
            if (window.Start <= start and start < window.End) skip = @max(skip, window.End);
            if (window.Start > start) end = @min(end, window.Start);
        }
        if (skip > start) {
            start = skip;
            continue;
        }
        const count = end - start;
        access.assign(manager.Index, .{ .Start = start, .End = end }, .Free);
        manager.Statistics.FreePages += count;
        manager.Statistics.ReservedPages -= count;
        manager.SearchStart = @min(manager.SearchStart, start);
        released += count;
        start = end;
    }
    return released;
}
