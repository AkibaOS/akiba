//! Sealed Backing Lifetime Without A Source Mapping

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.guest;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.guest;
const pmm = @import("mirai").pmm;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const baseline = user.state.ledger.count();
    const producer = try kata.create.create();
    var producer_live = true;
    defer if (producer_live) kata.destroy.destroy(producer) catch |failure| verify.failure(failure);
    try user.memory.allocate.allocate(producer, inputs.CODE_ADDRESS);
    try user.memory.load.load(producer, inputs.CODE_ADDRESS, &inputs.PAYLOAD);
    try user.memory.finalize.finalize(producer, inputs.CODE_ADDRESS, .ReadExecute);
    const frame = kagami.extract.extract(producer.AddressSpace.?, inputs.CODE_ADDRESS) orelse return error.InvalidFixture;
    const reference = user.memory.reference;
    var retained = try reference.retain(producer, inputs.CODE_ADDRESS);
    defer if (retained.Frame != null) reference.drop(&retained) catch |failure| verify.failure(failure);
    try kata.destroy.destroy(producer);
    producer_live = false;
    verify.require(protected(frame) and pmm.state.isAllocated(frame) and user.state.ledger.ownsPhysical(frame) and
        user.state.ledger.count() == baseline, labels.RETAIN_UNMAPPED);

    const receiver = try kata.create.create();
    var receiver_live = true;
    defer if (receiver_live) kata.destroy.destroy(receiver) catch |failure| verify.failure(failure);
    try reference.map(&retained, receiver, inputs.DATA_ADDRESS);
    try reference.drop(&retained);
    const dropped = if (reference.map(&retained, receiver, inputs.CODE_ADDRESS)) |_| false else |failure| failure == error.NotOwned;
    const mapped = kagami.extract.lookup(receiver.AddressSpace.?, inputs.DATA_ADDRESS) orelse return error.InvalidFixture;
    var bytes: [inputs.PAYLOAD.len]u8 = undefined;
    try user.copy.transfer.read(receiver, &bytes, inputs.DATA_ADDRESS);
    verify.require(dropped and mapped.PhysicalAddress == frame and mapped.Executable and !mapped.Writable and protected(frame) and
        std.mem.eql(u8, &bytes, &inputs.PAYLOAD), labels.RETAIN_ATTACH);
    try kata.destroy.destroy(receiver);
    receiver_live = false;
    verify.require(released(frame) and user.state.ledger.count() == baseline, labels.RETAIN_MAPPED_LAST);

    try releaseWithoutMapping(baseline);
}

fn releaseWithoutMapping(baseline: usize) !void {
    const reference = user.memory.reference;
    const producer = try kata.create.create();
    var live = true;
    defer if (live) kata.destroy.destroy(producer) catch |failure| verify.failure(failure);
    try user.memory.allocate.allocate(producer, inputs.DATA_ADDRESS);
    const refused = if (reference.retain(producer, inputs.DATA_ADDRESS)) |unexpected| unexpected_hold: {
        var retained = unexpected;
        reference.drop(&retained) catch |failure| verify.failure(failure);
        break :unexpected_hold false;
    } else |failure| failure == error.NotShareable;
    try user.memory.finalize.finalize(producer, inputs.DATA_ADDRESS, .ReadOnly);
    const frame = kagami.extract.extract(producer.AddressSpace.?, inputs.DATA_ADDRESS) orelse return error.InvalidFixture;
    var retained = try reference.retain(producer, inputs.DATA_ADDRESS);
    defer if (retained.Frame != null) reference.drop(&retained) catch |failure| verify.failure(failure);
    try kata.destroy.destroy(producer);
    live = false;
    const held = protected(frame) and pmm.state.isAllocated(frame);
    try reference.drop(&retained);
    verify.require(refused and held and released(frame) and user.state.ledger.count() == baseline, labels.RETAIN_UNMAPPED_LAST);
}

fn protected(frame: u64) bool {
    const alias = lookup(frame) orelse return false;
    return !alias.Writable and !alias.Executable and !alias.UserAccessible;
}

fn released(frame: u64) bool {
    const alias = lookup(frame) orelse return false;
    return !pmm.state.isAllocated(frame) and !user.state.ledger.ownsPhysical(frame) and alias.Writable and !alias.Executable and !alias.UserAccessible;
}

fn lookup(frame: u64) ?kagami.types.lookup.Lookup {
    return kagami.tables.walk.lookup(kagami.state.getKernelKagami().PML4Physical, common.constants.memory.layout.PHYSMAP_BASE + frame);
}
