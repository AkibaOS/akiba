//! Crimson Port Precedence And Bounds Checks

const crimson = @import("mirai").crimson;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.crimson;
const labels = @import("tests").strings.crimson;
const verify = @import("tests").verify;

const limits = crimson.constants.limits;
const ports = crimson.ports;
const Port = crimson.types.port.Port;

pub fn run() void {
    const flags = guard.acquire();
    defer guard.release(flags);
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
    verify.require(!ports.kata.setPort(limits.MAX_KATAS, .Breach, inputs.KATA_PORT, .Default, .General) and
        !ports.thread.setPort(limits.MAX_THREADS, .Breach, inputs.THREAD_PORT, .Default, .General) and
        !ports.kata.clearPort(limits.MAX_KATAS, .Breach) and !ports.thread.clearPort(limits.MAX_THREADS, .Breach) and
        !ports.kata.getPort(limits.MAX_KATAS, .Breach).isValid() and
        !ports.thread.getPort(limits.MAX_THREADS, .Breach).isValid(), labels.PORT_BOUNDS);
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
