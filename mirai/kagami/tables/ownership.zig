//! Indexed Root Owned Table Frame Lifetimes

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const labels = @import("mirai").kagami.strings.frames;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const tree = common.datatypes.tree;
const types = @import("mirai").kagami.types;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Frame = types.frame.Frame;
const FrameStore = memory.types.pool.store.create(Frame);
const Kagami = types.kagami.Kagami;
const Tree = tree.types.index.Tree;

var records: FrameStore = .{};
var physicals: Tree = .{};

pub fn find(physical: u64) ?*Frame {
    const flags = guard.acquire();
    defer guard.release(flags);
    const node = tree.lookup.find(&physicals, physical) orelse return null;
    return @fieldParentPtr(labels.INDEX, node);
}

pub fn owns(owner: *const Kagami, physical: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = find(physical) orelse return false;
    return record.Owner == owner and pmm.state.isAllocated(physical);
}

pub fn register(owner: *Kagami, physical: u64) AllocationError!*Frame {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!pmm.state.isAllocated(physical) or find(physical) != null) return AllocationError.InvalidSize;
    if (owner.TablePages == std.math.maxInt(u64)) return AllocationError.RegionExhausted;
    const record = try records.reserveNamed(labels.NAME);
    record.* = .{ .Owner = owner, .PA = physical };
    if (!tree.insert.insert(&physicals, &record.Index, physical)) {
        discard(record);
        return AllocationError.InvalidSize;
    }
    record.Next = owner.Frames;
    if (owner.Frames) |head| head.Previous = record;
    owner.Frames = record;
    owner.TablePages += 1;
    return record;
}

pub fn release(owner: *Kagami, physical: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = find(physical) orelse return false;
    if (record.Owner != owner or owner.TablePages == 0 or
        (if (record.Previous) |previous| previous.Next != record else owner.Frames != record) or
        (if (record.Next) |following| following.Previous != record else false)) return false;
    if (!tree.remove.remove(&physicals, &record.Index)) @panic(labels.INVALID_STATE);
    if (record.Previous) |previous| previous.Next = record.Next else owner.Frames = record.Next;
    if (record.Next) |following| following.Previous = record.Previous;
    owner.TablePages -= 1;
    discard(record);
    return true;
}

pub fn reset(owner: *const Kagami) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    var current = owner.Frames;
    var previous: ?*Frame = null;
    var count: u64 = 0;
    while (current) |record| {
        if (count == owner.TablePages or !records.owns(record)) return false;
        if (record.Owner != owner or record.Previous != previous or find(record.PA) != record or
            !pmm.state.isAllocated(record.PA)) return false;
        record.Visited = false;
        previous = record;
        current = record.Next;
        count += 1;
    }
    return count == owner.TablePages;
}

pub fn visit(owner: *const Kagami, physical: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = find(physical) orelse return false;
    if (record.Owner != owner or record.Visited or !pmm.state.isAllocated(physical)) return false;
    record.Visited = true;
    return true;
}

pub fn transfer(source: *Kagami, target: *Kagami) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (source == target or target.Frames != null or target.TablePages != 0 or !reset(source)) return false;
    var current = source.Frames;
    while (current) |record| : (current = record.Next) record.Owner = target;
    target.Frames = source.Frames;
    target.TablePages = source.TablePages;
    source.Frames = null;
    source.TablePages = 0;
    return true;
}

fn discard(record: *Frame) void {
    if (!records.release(record)) @panic(labels.INVALID_STATE);
    _ = records.collectAt(record);
    records.pruneEmpty();
}
