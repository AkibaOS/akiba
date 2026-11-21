//! Prove The Installed Pulse Runs As The First Persona Kata

const drive = @import("tests").guest.support.drive;
const harness = @import("tests").guest.postman.harness;
const kata = @import("mirai").kata;
const launch = @import("mirai").bootstrap.pulse.launch;
const postman = @import("mirai").postman;
const sensei = @import("mirai").sensei;
const status = @import("shared").pulse.constants.status;
const thread = @import("mirai").thread;

const Actor = @import("tests").guest.types.postman.fixtures.Actor;
const Context = @import("tests").guest.types.ahci.pulse.Context;
const Prepared = @import("mirai").bootstrap.types.image.preparation.Prepared;
const PulseError = @import("mirai").bootstrap.errors.pulse.launch.PulseError;
const Volume = @import("shared").boot.types.volume.Volume;
const WitnessError = @import("tests").guest.errors.ahci.witness.WitnessError;

pub fn prove(volume: Volume) !bool {
    const pulse = try launch.start(volume);
    drive.run();
    if (kata.state.first() != pulse.Owner or !waiting(pulse)) return false;
    if (launch.start(volume)) |_| {
        return false;
    } else |failure| {
        if (failure != PulseError.NotFirstKata) return failure;
    }

    var context: Context = .{ .PulseID = pulse.ID };
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
    context.Outcome = exchange(context.PulseID);
    thread.finish.complete();
}

fn exchange(identifier: u64) !bool {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try harness.descriptorFor(&client, identifier, status.QUERY, 0, 0);
    try harness.install(&client, &.{ harness.call(&client), harness.call(&client) });
    try harness.start(&client);
    try harness.waitStep(&client, 1);
    const ready = try replyIs(&client, 1, identifier, status.READY);
    try harness.descriptorFor(&client, identifier, status.QUERY, 1, 0);
    try harness.advance(&client, 1);
    try harness.waitStep(&client, 2);
    const refused = try replyIs(&client, 2, identifier, status.UNSUPPORTED);
    try harness.advance(&client, 2);
    return ready and refused;
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
