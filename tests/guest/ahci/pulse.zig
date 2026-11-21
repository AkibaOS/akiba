//! Prove The Installed Pulse Runs As The First Persona Kata

const std = @import("std");

const afs = @import("mirai").bootstrap.driver.afs;
const authority = @import("mirai").device.ahci.authority;
const drive = @import("tests").guest.support.drive;
const fixture = @import("tests").guest.constants.ahci.fixture;
const handoff = @import("mirai").bootstrap.storage.handoff;
const harness = @import("tests").guest.postman.harness;
const installed = @import("tests").guest.ahci.weaver;
const kata = @import("mirai").kata;
const launch = @import("mirai").bootstrap.pulse.launch;
const postman = @import("mirai").postman;
const sensei = @import("mirai").sensei;
const status = @import("shared").pulse.constants.status;
const thread = @import("mirai").thread;
const weaver = @import("mirai").bootstrap.weaver.handoff;

const Actor = @import("tests").guest.types.postman.fixtures.Actor;
const DeviceOperation = @import("shared").ahci.types.device.invocation.Operation;
const Context = @import("tests").guest.types.ahci.pulse.Context;
const Operation = @import("shared").pulse.types.boot.control.Operation;
const Prepared = @import("mirai").bootstrap.types.image.preparation.Prepared;
const PulseError = @import("mirai").bootstrap.errors.pulse.launch.PulseError;
const Volume = @import("shared").boot.types.volume.Volume;
const WitnessError = @import("tests").guest.errors.ahci.witness.WitnessError;

pub fn prove(volume: Volume) !bool {
    const pulse = try launch.start(volume);
    drive.run();
    if (kata.state.first() != pulse.Owner or !waiting(pulse) or !weaver.readyFor(pulse.ID)) return false;
    const resident = kata.state.next(pulse.Owner) orelse return false;
    const driver = kata.state.next(resident) orelse return false;
    const files = kata.state.next(driver) orelse return false;
    if (pulse.Owner.CanProvision or !resident.CanProvision or driver.CanProvision or files.CanProvision or kata.state.next(files) != null or
        !authority.readyFor(pulse.ID, driver.ID) or !afs.readyFor(pulse.ID, files.ID)) return false;
    const disk = handoff.forPulse(pulse.Owner) orelse return false;
    const address: u16 = @bitCast(disk.Location.Address);
    if (address != fixture.RELOCATED_ADDRESS or disk.Location.Port != fixture.BOOT_PORT or
        !std.meta.eql(disk.Volume, volume) or handoff.forPulse(resident) != null) return false;
    if (launch.start(volume)) |_| {
        return false;
    } else |failure| {
        if (failure != PulseError.NotFirstKata) return failure;
    }

    var context: Context = .{ .PulseID = pulse.ID, .WeaverID = resident.ID };
    const owner = try kata.create.create();
    const identifier = owner.ID;
    defer harness.dispose(identifier);
    try sensei.control.start(try thread.create.create(owner, monitor, &context));
    drive.run();
    const outcome = context.Outcome orelse return WitnessError.PulseProbeDidNotRun;
    return (try outcome) and waiting(pulse);
}

fn monitor(argument: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const context: *Context = @ptrCast(@alignCast(argument.?));
    context.Outcome = exercise(context);
    thread.finish.complete();
}

fn exercise(context: *const Context) !bool {
    return try exchange(context.PulseID) and try installed.prove(context.WeaverID);
}

fn exchange(identifier: u64) !bool {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try harness.descriptorFor(&client, identifier, status.QUERY, 0, 0);
    try harness.install(&client, &.{
        harness.call(&client),
        harness.call(&client),
        .{ .Service = .BootstrapWeaver, .First = .{ .Immediate = @intFromEnum(Operation.Start) } },
        .{ .Service = .Ahci, .First = .{ .Immediate = @intFromEnum(DeviceOperation.Describe) } },
    });
    try harness.start(&client);
    try harness.waitStep(&client, 1);
    const ready = try replyIs(&client, 1, identifier, status.READY);
    try harness.descriptorFor(&client, identifier, status.QUERY, 1, 0);
    try harness.advance(&client, 1);
    try harness.waitStep(&client, 2);
    const refused = try replyIs(&client, 2, identifier, status.UNSUPPORTED);
    try harness.advance(&client, 2);
    try harness.waitStep(&client, 3);
    const denied = try harness.resultIs(&client, 3, .InvalidCaller, 0);
    try harness.advance(&client, 3);
    try harness.waitStep(&client, 4);
    const disk_denied = try harness.resultIs(&client, 4, .InvalidCaller, 0);
    try harness.advance(&client, 4);
    return ready and refused and denied and disk_denied;
}

fn waiting(pulse: Prepared) bool {
    const mailbox = postman.inbox.find(pulse.Owner) orelse return false;
    return pulse.Owner.State == .Sleeping and pulse.Thread.Mode == .Persona and
        pulse.Thread.Status == .Blocked and !pulse.Thread.User.Faulted and mailbox.Receivers.Count == 1;
}

fn replyIs(actor: *const Actor, step: usize, sender: u64, kind: u64) !bool {
    const reply = try harness.header(actor);
    return try harness.resultIs(actor, step, .Success, 0) and reply.Sender == sender and
        reply.Type == kind and reply.Length == 0 and reply.ReplyTicket == 0;
}
