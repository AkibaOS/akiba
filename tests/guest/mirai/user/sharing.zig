//! Shared Sealed User Frame Reclamation

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.guest;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.guest;
const pmm = @import("mirai").pmm;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const Kata = kata.types.kata.Kata;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const baseline = user.state.ledger.count();
    const source = try kata.create.create();
    var source_live = true;
    defer if (source_live) kata.destroy.destroy(source) catch |failure| verify.failure(failure);
    const receiver = try kata.create.create();
    var receiver_live = true;
    defer if (receiver_live) kata.destroy.destroy(receiver) catch |failure| verify.failure(failure);
    try user.memory.allocate.allocate(source, inputs.CODE_ADDRESS);
    try user.memory.load.load(source, inputs.CODE_ADDRESS, &inputs.PAYLOAD);
    try user.memory.finalize.finalize(source, inputs.CODE_ADDRESS, .ReadExecute);
    const original = kagami.extract.lookup(source.AddressSpace.?, inputs.CODE_ADDRESS).?;
    const frame = original.PhysicalAddress;
    const shared = if (user.memory.share.map(source, inputs.CODE_ADDRESS, receiver, inputs.DATA_ADDRESS)) |_| true else |_| false;
    const mapping = kagami.extract.lookup(receiver.AddressSpace.?, inputs.DATA_ADDRESS);
    const rejected_write = if (user.copy.transfer.write(receiver, inputs.DATA_ADDRESS, &inputs.REPLACEMENT)) |_| false else |failure| failure == error.SealedPage;
    verify.require(shared and mapping != null and mapping.?.PhysicalAddress == frame and mapping.?.Executable and
        !mapping.?.Writable and rejected_write and protected(frame), labels.SHARED_FRAME);
    try checkRefusal(source);

    try kata.destroy.destroy(source);
    source_live = false;
    var bytes: [inputs.PAYLOAD.len]u8 = undefined;
    try user.copy.transfer.read(receiver, &bytes, inputs.DATA_ADDRESS);
    const retained = kagami.extract.lookup(receiver.AddressSpace.?, inputs.DATA_ADDRESS).?;
    verify.require(std.mem.eql(u8, &bytes, &inputs.PAYLOAD) and retained.PhysicalAddress == frame and
        retained.Executable and !retained.Writable and protected(frame) and pmm.state.isAllocated(frame) and
        user.state.ledger.ownsPhysical(frame), labels.SHARED_SURVIVES);
    try kata.destroy.destroy(receiver);
    receiver_live = false;
    const alias = aliasFor(frame);
    verify.require(!user.state.ledger.ownsPhysical(frame) and !pmm.state.isAllocated(frame) and
        alias.Writable and !alias.Executable and user.state.ledger.count() == baseline, labels.SHARED_LAST);
}

fn checkRefusal(source: *Kata) !void {
    const receiver = try kata.create.create();
    defer kata.destroy.destroy(receiver) catch |failure| verify.failure(failure);
    try user.memory.allocate.allocate(source, inputs.DATA_ADDRESS);
    const before = user.state.ledger.count();
    const mutable = if (user.memory.share.map(source, inputs.DATA_ADDRESS, receiver, inputs.DATA_ADDRESS)) |_| false else |failure| failure == error.NotShareable;
    const refused = pressure: {
        budget.arm(0);
        defer budget.clear();
        break :pressure if (user.memory.share.map(source, inputs.CODE_ADDRESS, receiver, inputs.DATA_ADDRESS)) |_| false else |failure| failure == error.OutOfMemory or failure == error.PageTableAllocationFailed;
    };
    verify.require(mutable and refused and user.state.ledger.count() == before and receiver.AddressSpace.?.ResidentPages == 0 and
        user.state.ledger.find(receiver, inputs.DATA_ADDRESS) == null, labels.SHARE_REFUSAL);
}

fn protected(frame: u64) bool {
    const alias = aliasFor(frame);
    return !alias.Writable and !alias.Executable and !alias.UserAccessible;
}

fn aliasFor(frame: u64) kagami.types.lookup.Lookup {
    return kagami.tables.walk.lookup(kagami.state.getKernelKagami().PML4Physical, common.constants.memory.layout.PHYSMAP_BASE + frame).?;
}
