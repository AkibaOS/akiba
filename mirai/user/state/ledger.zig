//! Stable Indexed Owned User Page Ledger

const checks = @import("mirai").user.state.checks;
const common = @import("common");
const fields = @import("mirai").user.strings.fields;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("mirai").user.strings.ledger;
const memory = @import("mirai").memory;
const tree = common.datatypes.tree;
const types = @import("mirai").user.types;
const usererrors = @import("mirai").user.errors.memory;

const sizes = common.constants.memory.sizes;
const Kagami = kagami.types.kagami.Kagami;
const Kata = kata.types.kata.Kata;
const Record = types.record.Record;
const RecordStore = memory.types.pool.store.create(Record);
const Tree = tree.types.index.Tree;
const UserError = usererrors.UserError;

var records: RecordStore = .{};
var virtuals: Tree = .{};
var physicals: Tree = .{};

pub fn count() usize {
    const flags = guard.acquire();
    defer guard.release(flags);
    return records.Count;
}

pub fn first(owner: *const Kata) ?*Record {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = kata.state.data(owner) orelse return null;
    return slot.Pages;
}

pub fn next(record: *const Record) ?*Record {
    const flags = guard.acquire();
    defer guard.release(flags);
    return if (records.owns(record)) record.Next else null;
}

pub fn find(owner: *const Kata, virtual_address: u64) ?*Record {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!kata.state.owns(owner)) return null;
    const root = owner.AddressSpace orelse return null;
    const record = findRoot(root, virtual_address) orelse return null;
    return if (record.Owner == owner) record else null;
}

pub fn findRoot(root: *const Kagami, virtual_address: u64) ?*Record {
    const flags = guard.acquire();
    defer guard.release(flags);
    const node = tree.lookup.find(&virtuals, virtualKey(root, virtual_address)) orelse return null;
    return @fieldParentPtr(fields.VIRTUAL_INDEX, node);
}

pub fn findPhysical(physical_address: u64) ?*Record {
    const flags = guard.acquire();
    defer guard.release(flags);
    const node = tree.lookup.find(&physicals, physical_address) orelse return null;
    return @fieldParentPtr(fields.PHYSICAL_INDEX, node);
}

pub fn ownsPhysical(physical_address: u64) bool {
    return findPhysical(physical_address) != null;
}

pub fn register(owner: *Kata, virtual_address: u64, physical_address: u64) UserError!*Record {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!checks.isValidOwner(owner)) return UserError.InvalidOwner;
    if ((virtual_address & sizes.PAGE_MASK) != 0) return UserError.AddressNotAligned;
    if (!checks.isValidRange(virtual_address, sizes.PAGE_SIZE)) return UserError.InvalidUserRange;
    if (!checks.isPayloadPhysical(physical_address)) return UserError.InvalidPhysmap;
    const root = owner.AddressSpace.?;
    if (findRoot(root, virtual_address) != null or ownsPhysical(physical_address)) return UserError.AlreadyOwned;
    if (records.Zone == null) try records.init(labels.NAME);
    const record = try records.reserve();
    record.* = .{ .Owner = owner, .Root = root, .VA = virtual_address, .PA = physical_address };
    if (!tree.insert.insert(&virtuals, &record.VirtualIndex, virtualKey(root, virtual_address))) {
        discard(record);
        return UserError.AlreadyOwned;
    }
    if (!tree.insert.insert(&physicals, &record.PhysicalIndex, physical_address)) {
        if (!tree.remove.remove(&virtuals, &record.VirtualIndex)) @panic(labels.INVALID_STATE);
        discard(record);
        return UserError.AlreadyOwned;
    }
    const slot = kata.state.data(owner).?;
    record.Next = slot.Pages;
    if (slot.Pages) |head| head.Previous = record;
    slot.Pages = record;
    return record;
}

pub fn unregister(record: *Record) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(record)) return;
    const slot = kata.state.data(record.Owner) orelse @panic(labels.INVALID_STATE);
    if (findRoot(record.Root, record.VA) != record or findPhysical(record.PA) != record or
        (if (record.Previous) |previous| previous.Next != record else slot.Pages != record) or
        (if (record.Next) |following| following.Previous != record else false)) @panic(labels.INVALID_STATE);
    if (!tree.remove.remove(&virtuals, &record.VirtualIndex) or
        !tree.remove.remove(&physicals, &record.PhysicalIndex)) @panic(labels.INVALID_STATE);
    if (record.Previous) |previous| previous.Next = record.Next else slot.Pages = record.Next;
    if (record.Next) |following| following.Previous = record.Previous;
    discard(record);
}

fn virtualKey(root: *const Kagami, virtual_address: u64) u128 {
    return (@as(u128, @intFromPtr(root)) << @bitSizeOf(u64)) | virtual_address;
}

fn discard(record: *Record) void {
    if (!records.release(record)) @panic(labels.INVALID_STATE);
    _ = records.collectAt(record);
}
