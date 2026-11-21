//! Read Real Installed Keyboard Events Through Its Postman Inbox

const std = @import("std");

const challenge = @import("tests").phase.constants.input;
const copy = @import("mirai").user.copy.transfer;
const fixture = @import("tests").guest.constants.ahci.fixture;
const harness = @import("tests").guest.postman.harness;
const inputwire = @import("tests").phase.strings.input;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.drivers.input;
const locations = @import("tests").guest.constants.postman.transport;
const print = @import("mirai").boot.sequence.print;
const protocol = @import("shared").keyboard.constants.postman;
const verify = @import("tests").guest.support.verify;

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
    try harness.install(&client, &([_]@TypeOf(harness.call(&client)){harness.call(&client)} ** (challenge.EVENT_COUNT + 1)));
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
    try harness.advance(&client, final);
}
