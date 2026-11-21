//! Read Real Installed Keyboard Events Through Its Postman Inbox

const std = @import("std");

const challenge = @import("tests").phase.constants.input;
const copy = @import("mirai").user.copy.transfer;
const fixture = @import("tests").guest.constants.ahci.fixture;
const harness = @import("tests").guest.postman.harness;
const inputwire = @import("tests").phase.strings.input;
const instances = @import("mirai").device.instance.registry;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.drivers.input;
const locations = @import("tests").guest.constants.postman.transport;
const ports = @import("mirai").drivers.constants.keyboard.ports;
const print = @import("mirai").boot.sequence.print;
const protocol = @import("shared").keyboard.constants.postman;
const sensei = @import("mirai").sensei;
const service = @import("shared").pulse.constants.supervision.protocol;
const timing = @import("tests").fixtures.constants.service;
const verify = @import("tests").guest.support.verify;

const Actor = @import("tests").guest.types.postman.fixtures.Actor;
const Event = @import("shared").keyboard.types.event.Event;
const WitnessError = @import("tests").guest.errors.ahci.witness.WitnessError;

pub fn prove(pulse: u64, keyboard: u64) !void {
    const owner = kata.state.findByID(pulse) orelse return WitnessError.KeyboardDriverMissing;
    var client = try harness.attach(.{
        .Owner = owner,
        .ID = pulse,
        .Code = fixture.KEYBOARD_CODE,
        .Data = fixture.KEYBOARD_DATA,
        .Stack = fixture.KEYBOARD_STACK,
    });
    try harness.install(&client, &([_]@TypeOf(harness.call(&client)){harness.call(&client)} ** (challenge.EVENT_COUNT + 2)));
    try harness.descriptorFor(&client, keyboard, protocol.READ, 0, @sizeOf(Event));
    try harness.start(&client);
    for (1..challenge.EVENT_COUNT + 1) |step| {
        try harness.waitStep(&client, step);
        const header = try harness.header(&client);
        if (!try harness.resultIs(&client, step, .Success, @sizeOf(Event)) or header.Sender != keyboard or
            header.Type != protocol.EVENT or header.Length != @sizeOf(Event) or header.ReplyTicket != 0) return WitnessError.InvalidKeyboardEvent;
        var event: Event = undefined;
        try copy.read(owner, std.mem.asBytes(&event), client.Data + locations.OUTPUT_OFFSET);
        if (event.Reserved != 0 or @as(u8, @bitCast(event.Modifiers)) != 0) return WitnessError.InvalidKeyboardEvent;
        print.log(inputwire.EVENT_LINE, .{ @intFromEnum(event.Kind), event.Value });
        try harness.advance(&client, step);
    }
    const final = challenge.EVENT_COUNT + 1;
    try harness.waitStep(&client, final);
    const empty = try harness.header(&client);
    verify.require(try harness.resultIs(&client, final, .Success, 0) and empty.Sender == keyboard and
        empty.Type == protocol.EMPTY and empty.Length == 0 and empty.ReplyTicket == 0, labels.NORMALIZED);
    try rebind(&client, keyboard, final);
}

fn rebind(client: *const Actor, keyboard: u64, final: u64) !void {
    const original = kata.state.findByID(keyboard) orelse return WitnessError.KeyboardDriverMissing;
    const handle = instances.handleFor(original) orelse return WitnessError.KeyboardDriverMissing;
    const device = instances.find(.Keyboard, ports.IRQ) orelse return WitnessError.KeyboardDriverMissing;
    try harness.descriptorFor(client, keyboard, service.SERVICE_STOP, 0, 0);
    try harness.advance(client, final);
    try harness.waitTimedStep(client, final + 1, timing.TIMEOUT_TICKS);
    const stopped = try harness.header(client);
    const replied = try harness.resultIs(client, @intCast(final + 1), .Success, 0) and stopped.Sender == keyboard and stopped.Type == service.SERVICE_STOPPED;
    try harness.advance(client, final + 1);
    const deadline = sensei.state.getState().Ticks + timing.RECOVERY_TICKS;
    while (sensei.state.getState().Ticks < deadline) {
        if (instances.assignedOwner(device)) |replacement| {
            if (replacement.ID != keyboard) {
                const fresh = instances.handleFor(replacement) orelse return WitnessError.KeyboardDriverMissing;
                verify.require(replied and fresh != handle and instances.resolve(replacement, handle) == null and
                    kata.completion.storage.ownerOf(replacement.ID) == client.ID, labels.REBOUND_DRIVER);
                return;
            }
        }
        try sensei.run.yield();
    }
    verify.require(false, labels.REBOUND_DRIVER);
}
