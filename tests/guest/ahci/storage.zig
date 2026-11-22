//! Exercise Two Real AHCI Instances And Secondary Driver Reattachment

const std = @import("std");

const attachment = @import("mirai").device.ahci.attachment;
const codec = @import("shared").ahci.discover.location;
const copy = @import("mirai").user.copy.transfer;
const fixture = @import("tests").phase.constants.storage;
const harness = @import("tests").guest.postman.harness;
const instances = @import("mirai").device.instance.registry;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.drivers.input;
const locations = @import("tests").guest.constants.postman.transport;
const magic = @import("shared").afs.constants.magic;
const protocol = @import("shared").ahci.constants.device.postman;
const quarantine = @import("mirai").device.ahci.quarantine;
const sensei = @import("mirai").sensei;
const service = @import("shared").pulse.constants.supervision.protocol;
const timing = @import("tests").fixtures.constants.service;
const verify = @import("tests").guest.support.verify;

const Actor = @import("tests").guest.types.postman.fixtures.Actor;
const Call = @import("shared").persona.types.call.Call;
const DeviceOperation = @import("shared").device.types.operation.Operation;
const Operation = @import("tests").guest.types.postman.fixtures.Operation;
const Read = @import("shared").ahci.types.device.invocation.Read;

pub fn prove(pulse: u64, primary: u64) !void {
    const device = instances.find(.Ahci, fixture.LOCATION) orelse return error.SecondaryDeviceMissing;
    const secondary = instances.assignedOwner(device) orelse return error.SecondaryDriverMissing;
    const identifier = secondary.ID;
    const previous = instances.handleFor(secondary) orelse return error.SecondaryDriverMissing;
    var client = try harness.attach(.{ .Owner = kata.state.findByID(pulse).?, .ID = pulse, .Code = fixture.CODE, .Data = fixture.DATA, .Stack = fixture.STACK });
    try harness.install(&client, &([_]Operation{harness.call(&client)} ** 10));
    try read(&client, primary, 1, false);
    try read(&client, identifier, 2, true);
    verify.require(primary != identifier, labels.TWO_DISKS);
    try harness.descriptorFor(&client, identifier, service.SERVICE_STOP, 0, 0);
    try harness.advance(&client, 2);
    try expect(&client, identifier, 3, service.SERVICE_STOPPED, 0);
    const until = sensei.state.getState().Ticks + timing.RECOVERY_TICKS;
    while (sensei.state.getState().Ticks < until) {
        if (instances.assignedOwner(device)) |replacement| {
            if (replacement.ID != identifier) {
                const handle = instances.handleFor(replacement) orelse return error.SecondaryDriverMissing;
                try harness.descriptorFor(&client, replacement.ID, service.SERVICE_QUERY, 0, 0);
                try harness.advance(&client, 3);
                try expect(&client, replacement.ID, 4, service.SERVICE_READY, 0);
                try stale(replacement.ID, previous, handle);
                try read(&client, primary, 5, false);
                try read(&client, replacement.ID, 6, true);
                verify.require(handle != previous, labels.REBOUND_DISK);
                const outside: u64 = fixture.LAST - fixture.FIRST + 1;
                try harness.input(&client, std.mem.asBytes(&outside));
                try harness.descriptorFor(&client, replacement.ID, protocol.READ, @sizeOf(u64), 0);
                try harness.advance(&client, 6);
                try expect(&client, replacement.ID, 7, protocol.REFUSED, 0);
                try read(&client, replacement.ID, 8, true);
                verify.require(true, labels.READ_REFUSAL);
                const location = try codec.decode(fixture.LOCATION);
                try attachment.verifyDetached(location);
                quarantine.retain(location.Address);
                const pending = try kata.create.createFor(client.Owner);
                defer kata.destroy.destroy(pending) catch @panic(labels.DISK_CLEANUP);
                if (instances.reserve(device, pending)) |_| return error.UnavailableDiskRebound else |failure| {
                    if (failure != error.InvalidTarget) return failure;
                }
                try read(&client, primary, 9, false);
                verify.require(true, labels.BLOCKED_CONTROLLER);
                try harness.descriptorFor(&client, replacement.ID, service.SERVICE_QUERY, 0, 0);
                try harness.advance(&client, 9);
                try harness.waitTimedStep(&client, 10, timing.TIMEOUT_TICKS);
                verify.require(try harness.resultIs(&client, 10, .PeerGone, 0), labels.UNAVAILABLE_READY);
                try harness.advance(&client, 10);
                return;
            }
        }
        try sensei.run.yield();
    }
    return error.SecondaryRebindDeadline;
}

fn read(client: *const Actor, identifier: u64, step: usize, secondary: bool) !void {
    const sector: u64 = 0;
    try harness.input(client, std.mem.asBytes(&sector));
    try harness.descriptorFor(client, identifier, protocol.READ, @sizeOf(u64), fixture.BLOCK_BYTES);
    var descriptor: Call = undefined;
    try copy.read(client.Owner, std.mem.asBytes(&descriptor), client.Data + locations.CALL_OFFSET);
    descriptor.Reply = client.Data + fixture.OUTPUT;
    try copy.write(client.Owner, client.Data + locations.CALL_OFFSET, std.mem.asBytes(&descriptor));
    if (step == 1) try harness.start(client) else try harness.advance(client, step - 1);
    try expect(client, identifier, step, protocol.SECTOR, fixture.BLOCK_BYTES);
    var bytes: [fixture.BLOCK_BYTES]u8 = undefined;
    try copy.read(client.Owner, &bytes, client.Data + fixture.OUTPUT);
    if (secondary) {
        if (!std.mem.allEqual(u8, &bytes, fixture.SENTINEL)) return error.WrongSecondaryData;
    } else if (std.mem.readInt(u64, bytes[0..@sizeOf(u64)], .little) != magic.SIGNATURE) return error.WrongPrimaryData;
}

fn stale(identifier: u64, previous: u64, handle: u64) !void {
    const owner = kata.state.findByID(identifier) orelse return error.SecondaryDriverMissing;
    var caller = try harness.attach(.{ .Owner = owner, .ID = identifier, .Code = fixture.CODE, .Data = fixture.DATA, .Stack = fixture.STACK });
    const request: Read = .{ .Sector = fixture.FIRST, .Destination = caller.Data + fixture.OUTPUT };
    try harness.input(&caller, std.mem.asBytes(&request));
    const invalid: Operation = .{ .Service = .Device, .First = .{ .Immediate = @intFromEnum(DeviceOperation.BlockRead) }, .Second = previous, .Third = caller.Data + locations.INPUT_OFFSET };
    var valid = invalid;
    valid.Second = handle;
    try harness.install(&caller, &.{ invalid, valid });
    try harness.start(&caller);
    try harness.waitStep(&caller, 1);
    const denied = try harness.resultIs(&caller, 1, .InvalidCaller, 0);
    try harness.advance(&caller, 1);
    try harness.waitStep(&caller, 2);
    verify.require(denied and try harness.resultIs(&caller, 2, .Success, 0), labels.STALE_DISK);
    try harness.advance(&caller, 2);
}

fn expect(client: *const Actor, identifier: u64, step: usize, kind: u64, length: usize) !void {
    try harness.waitTimedStep(client, step, timing.TIMEOUT_TICKS);
    const header = try harness.header(client);
    if (!try harness.resultIs(client, step, .Success, length) or header.Sender != identifier or header.Type != kind or header.Length != length or header.ReplyTicket != 0) return error.InvalidDiskReply;
}
