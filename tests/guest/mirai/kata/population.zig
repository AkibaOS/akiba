//! Growable Kata And Address Space Populations

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.pool;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.retention;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const Kata = kata.types.kata.Kata;

var owners = [_]?*Kata{null} ** inputs.LIVE_COUNT;
var identifiers = [_]u64{0} ** inputs.LIVE_COUNT;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const kernel = kata.state.getKernel().?;
    const initial = try kata.create.createFor(kernel);
    try kata.destroy.destroy(initial);
    const before = pmm.state.getStatistics();
    defer {
        for (&owners) |*entry| {
            if (entry.*) |owner| kata.destroy.destroy(owner) catch |failure| verify.failure(failure);
            entry.* = null;
        }
    }
    var retained = true;
    var previous: u64 = 0;
    for (&owners, &identifiers) |*entry, *identifier| {
        const owner = try kata.create.createFor(kernel);
        entry.* = owner;
        identifier.* = owner.ID;
        retained = retained and owner.ID > previous and owner.State == .Born and owner.ThreadCount == 0 and
            owner.AddressSpace.?.ExecutionOwners == 1 and kagami.create.owns(owner.AddressSpace.?);
        previous = owner.ID;
    }
    for (owners, identifiers, 0..) |entry, identifier, index| {
        const owner = entry.?;
        retained = retained and kata.state.findByID(identifier) == owner and kata.state.owns(owner) and
            owner.ID == identifier and owner.State == .Born;
        for (owners[0..index]) |other| retained = retained and owner != other.? and owner.AddressSpace != other.?.AddressSpace;
    }
    verify.require(retained, labels.POPULATION);
    for (&owners, identifiers, 0..) |*entry, identifier, index| {
        if (index % 2 != 0) continue;
        try kata.destroy.destroy(entry.*.?);
        entry.* = null;
        retained = retained and kata.state.findByID(identifier) == null and kata.completion.storage.ownerOf(identifier) == null;
    }
    for (owners, identifiers) |entry, identifier| {
        if (entry) |owner| {
            retained = retained and kata.state.findByID(identifier) == owner and kata.state.owns(owner) and
                owner.ID == identifier and kagami.create.owns(owner.AddressSpace.?) and owner.AddressSpace.?.ExecutionOwners == 1;
        }
    }
    verify.require(retained, labels.POPULATION_RELEASE);
    for (&owners) |*entry| {
        if (entry.*) |owner| try kata.destroy.destroy(owner);
        entry.* = null;
    }
    for (identifiers) |identifier| retained = retained and kata.state.findByID(identifier) == null and
        kata.completion.storage.ownerOf(identifier) == null;
    verify.require(retained and std.meta.eql(before, pmm.state.getStatistics()), labels.POPULATION_UNWIND);
}
