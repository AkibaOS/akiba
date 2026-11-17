//! Crimson Port Precedence Sparse Ownership And Failure Checks

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const crimson = @import("mirai").crimson;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.crimson;
const labels = @import("tests").strings.crimson;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

const ports = crimson.ports;
const Port = crimson.types.port.Port;

pub fn run() void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const search = pmm.state.getState().SearchStart;
    defer pmm.state.getState().SearchStart = search;
    defer budget.clear();
    const saved_host = ports.host.getPort(.Breach).*;
    const saved_kata = ports.kata.getPort(inputs.KATA_ID, .Breach).*;
    const saved_thread = ports.thread.getPort(inputs.THREAD_ID, .Breach).*;
    defer restore(saved_host, saved_kata, saved_thread);
    ports.host.clearPort(.Breach);
    _ = ports.kata.clearPort(inputs.KATA_ID, .Breach);
    _ = ports.thread.clearPort(inputs.THREAD_ID, .Breach);
    ports.host.setPort(.Breach, inputs.HOST_PORT, .Default, .General);
    const host = ports.lookup.findPortFor(inputs.THREAD_ID, inputs.KATA_ID, .Breach);
    const mask = ports.mask.add(0, .Breach);
    verify.require(host.Found and host.Port.Owner == .Host and host.Port.PortId == inputs.HOST_PORT and
        ports.mask.includes(mask, .Breach) and !ports.mask.includes(mask, .Overflow) and
        ports.mask.remove(mask, .Breach) == 0, labels.PORT_HOST);
    verify.require(ports.kata.setPort(inputs.KATA_ID, .Breach, inputs.KATA_PORT, .State, .Full), labels.PORT_KATA);
    const owner = ports.lookup.findPortFor(inputs.THREAD_ID, inputs.KATA_ID, .Breach);
    verify.require(owner.Found and owner.Port.Owner == .Kata and owner.Port.OwnerId == inputs.KATA_ID and
        owner.Port.PortId == inputs.KATA_PORT and owner.Port.Behavior == .State and owner.Port.Flavor == .Full, labels.PORT_KATA);
    verify.require(ports.thread.setPort(inputs.THREAD_ID, .Breach, inputs.THREAD_PORT, .StateIdentity, .Debug), labels.PORT_THREAD);
    const target = ports.lookup.findPortFor(inputs.THREAD_ID, inputs.KATA_ID, .Breach);
    verify.require(target.Found and target.Port.Owner == .Thread and target.Port.OwnerId == inputs.THREAD_ID and
        target.Port.PortId == inputs.THREAD_PORT and target.Port.Behavior == .StateIdentity and target.Port.Flavor == .Debug, labels.PORT_THREAD);
    _ = ports.thread.clearPort(inputs.THREAD_ID, .Breach);
    verify.require(ports.lookup.findPortFor(inputs.THREAD_ID, inputs.KATA_ID, .Breach).Port.PortId == inputs.KATA_PORT, labels.PORT_FALLBACK);
    _ = ports.kata.clearPort(inputs.KATA_ID, .Breach);
    verify.require(ports.lookup.findPortFor(inputs.THREAD_ID, inputs.KATA_ID, .Breach).Port.PortId == inputs.HOST_PORT, labels.PORT_FALLBACK);
    ports.host.clearPort(.Breach);
    verify.require(!ports.lookup.findPortFor(inputs.THREAD_ID, inputs.KATA_ID, .Breach).Found and
        !ports.lookup.hasAnyPort(inputs.THREAD_ID, inputs.KATA_ID, .Breach), labels.PORT_FALLBACK);
    highIds();
    growth();
    failure();
}

fn highIds() void {
    var registered = true;
    var slots = true;
    for (inputs.PORT_HIGH_IDS) |id| {
        const owner = ports.kata.setPort(id, .Breach, inputs.KATA_PORT, .State, .Full);
        const target = ports.thread.setPort(id, .Breach, inputs.THREAD_PORT, .StateIdentity, .Debug);
        if (!owner or !target) {
            _ = ports.kata.clearAllForKata(id);
            _ = ports.thread.clearAllForThread(id);
            verify.require(false, labels.PORT_HIGH_IDS);
            return;
        }
        const chosen = ports.lookup.findPortFor(id, id, .Breach);
        registered = registered and chosen.Found and chosen.Port.Owner == .Thread and chosen.Port.OwnerId == id and
            chosen.Port.PortId == inputs.THREAD_PORT and ports.kata.getPort(id, .Breach).OwnerId == id;
        const extra = ports.kata.setPort(id, .Overflow, inputs.HOST_PORT, .Default, .General);
        const retained = ports.kata.getPort(id, .Overflow);
        budget.arm(0);
        const zero = ports.kata.setPort(id, .Resource, 0, .StateIdentity, .Debug);
        const zero_port = ports.kata.getPort(id, .Resource).*;
        const updated_owner = ports.kata.setPort(id, .Breach, inputs.PORT_UPDATED_KATA, .Default, .General);
        const updated_target = ports.thread.setPort(id, .Breach, inputs.PORT_UPDATED_THREAD, .State, .Full);
        const selected = ports.lookup.findPortFor(id, id, .Breach);
        const selected_intact = selected.Found and selected.Port.PortId == inputs.PORT_UPDATED_THREAD and selected.Port.OwnerId == id;
        const cleared_owner = ports.kata.clearPort(id, .Breach);
        const retained_intact = ports.kata.hasPort(id, .Overflow) and retained == ports.kata.getPort(id, .Overflow) and
            retained.PortId == inputs.HOST_PORT and retained.OwnerId == id and retained.Behavior == .Default and retained.Flavor == .General;
        const cleared_target = ports.thread.clearPort(id, .Breach);
        const no_breach = !ports.lookup.findPortFor(id, id, .Breach).Found;
        const cleared_all_owner = ports.kata.clearAllForKata(id);
        const cleared_all_target = ports.thread.clearAllForThread(id);
        budget.clear();
        slots = slots and extra and zero and zero_port.Active and zero_port.PortId == 0 and zero_port.OwnerId == id and
            zero_port.Owner == .Kata and zero_port.Behavior == .StateIdentity and zero_port.Flavor == .Debug and
            updated_owner and updated_target and selected_intact and cleared_owner and retained_intact and cleared_target and
            no_breach and cleared_all_owner and cleared_all_target and
            std.meta.eql(Port.EMPTY, ports.kata.getPort(id, .Overflow).*) and std.meta.eql(Port.EMPTY, ports.thread.getPort(id, .Breach).*);
    }
    verify.require(registered, labels.PORT_HIGH_IDS);
    verify.require(slots, labels.PORT_SLOTS);
}

fn growth() void {
    collectMetadata();
    const before = pmm.state.getStatistics();
    var count: usize = 0;
    defer clearOwners(inputs.PORT_GROWTH_BASE, count);
    var retained_owner: ?*const Port = null;
    var retained_target: ?*const Port = null;
    while (count < inputs.PORT_GROWTH_COUNT) : (count += 1) {
        const id = ownerId(inputs.PORT_GROWTH_BASE, count);
        const owner = ports.kata.setPort(id, .Breach, inputs.PORT_GROWTH_KATA + count, .State, .Full);
        const target = ports.thread.setPort(id, .Breach, inputs.PORT_GROWTH_THREAD + count, .StateIdentity, .Debug);
        if (!owner or !target) {
            clearOwners(inputs.PORT_GROWTH_BASE, count + 1);
            verify.require(false, labels.PORT_GROWTH);
            return;
        }
        if (count == 1) {
            retained_owner = ports.kata.getPort(id, .Breach);
            retained_target = ports.thread.getPort(id, .Breach);
        }
    }
    const allocated = pmm.state.getStatistics();
    budget.arm(0);
    var intact = allocated.FreePages < before.FreePages;
    const queried = pmm.state.getStatistics();
    for (0..count) |index| {
        const id = ownerId(inputs.PORT_GROWTH_BASE, index);
        const owner = ports.kata.getPort(id, .Breach);
        const target = ports.thread.getPort(id, .Breach);
        const chosen = ports.lookup.findPortFor(id, id, .Breach);
        intact = intact and owner.isValid() and owner.Owner == .Kata and owner.OwnerId == id and owner.PortId == inputs.PORT_GROWTH_KATA + index and
            target.isValid() and target.Owner == .Thread and target.OwnerId == id and target.PortId == inputs.PORT_GROWTH_THREAD + index and
            chosen.Found and chosen.Port == target;
    }
    const no_lookup_allocation = std.meta.eql(queried, pmm.state.getStatistics());
    var cleared = true;
    for (0..count) |index| {
        if (index % 2 != 0) continue;
        const id = ownerId(inputs.PORT_GROWTH_BASE, index);
        const owner = ports.kata.clearPort(id, .Breach);
        const target = ports.thread.clearPort(id, .Breach);
        cleared = cleared and owner and target and !ports.kata.hasPort(id, .Breach) and !ports.thread.hasPort(id, .Breach);
    }
    const retained_id = ownerId(inputs.PORT_GROWTH_BASE, 1);
    const stable = retained_owner != null and retained_target != null and
        retained_owner.? == ports.kata.getPort(retained_id, .Breach) and retained_target.? == ports.thread.getPort(retained_id, .Breach) and
        retained_owner.?.PortId == inputs.PORT_GROWTH_KATA + 1 and retained_target.?.PortId == inputs.PORT_GROWTH_THREAD + 1;
    for (0..count) |index| {
        if (index % 2 == 0) continue;
        const id = ownerId(inputs.PORT_GROWTH_BASE, index);
        const owner = ports.kata.clearAllForKata(id);
        const target = ports.thread.clearAllForThread(id);
        cleared = cleared and owner and target and !ports.kata.hasPort(id, .Breach) and !ports.thread.hasPort(id, .Breach);
    }
    budget.clear();
    count = 0;
    collectMetadata();
    verify.require(intact and no_lookup_allocation, labels.PORT_GROWTH);
    verify.require(stable, labels.PORT_STABLE);
    verify.require(cleared and std.meta.eql(before, pmm.state.getStatistics()), labels.PORT_RELEASE);
}

fn failure() void {
    collectMetadata();
    const before = pmm.state.getStatistics();
    const seed = inputs.PORT_FAILURE_BASE;
    const owner = ports.kata.setPort(seed, .Breach, inputs.KATA_PORT, .State, .Full);
    const target = ports.thread.setPort(seed, .Breach, inputs.THREAD_PORT, .StateIdentity, .Debug);
    if (!owner or !target) {
        clearOwners(seed, 1);
        verify.require(false, labels.PORT_FAILURE);
        return;
    }
    var count: usize = 1;
    defer clearOwners(seed, count);
    budget.arm(0);
    const updated_owner = ports.kata.setPort(seed, .Breach, inputs.PORT_UPDATED_KATA, .Default, .General);
    const updated_target = ports.thread.setPort(seed, .Breach, inputs.PORT_UPDATED_THREAD, .State, .Full);
    const absent_before = pmm.state.getStatistics();
    const absent_owner = ports.kata.clearPort(inputs.PORT_UNUSED_ID, .Guard);
    const absent_target = ports.thread.clearAllForThread(inputs.PORT_UNUSED_ID);
    const absent = absent_owner and absent_target and !ports.kata.hasPort(inputs.PORT_UNUSED_ID, .Guard) and
        !ports.thread.hasPort(inputs.PORT_UNUSED_ID, .Guard) and std.meta.eql(Port.EMPTY, ports.kata.getPort(inputs.PORT_UNUSED_ID, .Guard).*) and
        std.meta.eql(absent_before, pmm.state.getStatistics());
    var rejected = false;
    var preserved = updated_owner and updated_target;
    while (count < inputs.PORT_FAILURE_LIMIT) : (count += 1) {
        const id = ownerId(seed, count);
        const snapshot = pmm.state.getStatistics();
        const search = pmm.state.getState().SearchStart;
        const added_owner = ports.kata.setPort(id, .Breach, inputs.KATA_PORT, .Default, .General);
        const added_target = ports.thread.setPort(id, .Breach, inputs.THREAD_PORT, .Default, .General);
        if (added_owner and added_target) continue;
        preserved = preserved and std.meta.eql(snapshot, pmm.state.getStatistics()) and search == pmm.state.getState().SearchStart and
            (added_owner or std.meta.eql(Port.EMPTY, ports.kata.getPort(id, .Breach).*)) and
            (added_target or std.meta.eql(Port.EMPTY, ports.thread.getPort(id, .Breach).*)) and
            ports.kata.getPort(seed, .Breach).PortId == inputs.PORT_UPDATED_KATA and ports.thread.getPort(seed, .Breach).PortId == inputs.PORT_UPDATED_THREAD;
        _ = ports.kata.clearAllForKata(id);
        _ = ports.thread.clearAllForThread(id);
        rejected = true;
        break;
    }
    clearOwners(seed, count);
    count = 0;
    budget.clear();
    collectMetadata();
    verify.require(absent, labels.PORT_NOALLOC);
    verify.require(rejected and preserved, labels.PORT_FAILURE);
    const recovered_owner = ports.kata.setPort(seed, .Breach, inputs.KATA_PORT, .State, .Full);
    const recovered_target = ports.thread.setPort(seed, .Breach, inputs.THREAD_PORT, .StateIdentity, .Debug);
    const selected = ports.lookup.findPortFor(seed, seed, .Breach);
    const recovered = selected.Found and selected.Port.Owner == .Thread and selected.Port.PortId == inputs.THREAD_PORT;
    clearOwners(seed, 1);
    collectMetadata();
    verify.require(recovered_owner and recovered_target and recovered and std.meta.eql(before, pmm.state.getStatistics()), labels.PORT_RECOVERY);
}

fn ownerId(base: u64, index: usize) u64 {
    return base + @as(u64, @intCast(index)) * inputs.PORT_OWNER_STRIDE;
}

fn clearOwners(base: u64, count: usize) void {
    for (0..count) |index| {
        const id = ownerId(base, index);
        _ = ports.kata.clearAllForKata(id);
        _ = ports.thread.clearAllForThread(id);
    }
}

fn collectMetadata() void {
    _ = memory.zone.gc.collect(memory.zone.bootstrap.getZoneZone());
    _ = memory.zone.gc.collect(memory.zone.bootstrap.getPageMetaZone());
}

fn restore(host: Port, owner: Port, target: Port) void {
    if (host.Active) ports.host.setPort(.Breach, host.PortId, host.Behavior, host.Flavor) else ports.host.clearPort(.Breach);
    if (owner.Active) {
        _ = ports.kata.setPort(inputs.KATA_ID, .Breach, owner.PortId, owner.Behavior, owner.Flavor);
    } else _ = ports.kata.clearPort(inputs.KATA_ID, .Breach);
    if (target.Active) {
        _ = ports.thread.setPort(inputs.THREAD_ID, .Breach, target.PortId, target.Behavior, target.Flavor);
    } else _ = ports.thread.clearPort(inputs.THREAD_ID, .Breach);
}
