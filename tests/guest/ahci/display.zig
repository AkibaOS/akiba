//! Draw And Refuse Real Display Requests Before Native Scanout Verification

const std = @import("std");

const copy = @import("mirai").user.copy.transfer;
const fixture = @import("tests").guest.constants.ahci.fixture;
const harness = @import("tests").guest.postman.harness;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.drivers.input;
const locations = @import("tests").guest.constants.postman.transport;
const pattern = @import("tests").phase.constants.display;
const print = @import("mirai").boot.sequence.print;
const protocol = @import("shared").display.constants.postman;
const screen = @import("tests").guest.screen.control;
const service = @import("shared").pulse.constants.supervision.protocol;
const verify = @import("tests").guest.support.verify;
const wire = @import("tests").phase.strings.display;

const Actor = @import("tests").guest.types.postman.fixtures.Actor;
const Mode = @import("shared").display.types.mode.Mode;
const Operation = @import("tests").guest.types.postman.fixtures.Operation;
const Rectangle = @import("shared").display.types.rectangle.Rectangle;
const WitnessError = @import("tests").guest.errors.ahci.witness.WitnessError;

pub fn prove(pulse: u64, display: u64) !void {
    const owner = kata.state.findByID(pulse) orelse return WitnessError.DisplayDriverMissing;
    var client = try harness.attach(.{
        .Owner = owner,
        .ID = pulse,
        .Code = fixture.DISPLAY_CODE,
        .Data = fixture.DISPLAY_DATA,
        .Stack = fixture.DISPLAY_STACK,
    });
    try harness.install(&client, &([_]Operation{harness.call(&client)} ** 4));
    try harness.descriptorFor(&client, display, protocol.QUERY, 0, @sizeOf(Mode));
    try harness.start(&client);
    try expectReply(&client, display, 1, protocol.MODE, @sizeOf(Mode));
    var mode: Mode = undefined;
    try copy.read(owner, std.mem.asBytes(&mode), client.Data + locations.OUTPUT_OFFSET);
    if (!mode.isValid() or mode.Width < pattern.WIDTH or mode.Height < pattern.TOP + pattern.HEIGHT)
        return WitnessError.InvalidDisplayReply;
    const left = mode.Width - pattern.WIDTH;
    screen.release();

    const background = [_][pattern.RGB_BYTES]u8{pattern.BACKGROUND} ** (pattern.WIDTH * pattern.HEIGHT);
    try paint(&client, display, 2, .{ .X = left, .Y = pattern.TOP, .Width = pattern.WIDTH, .Height = pattern.HEIGHT }, std.mem.asBytes(&background), protocol.PRESENTED);
    var patch: [pattern.INNER][pattern.INNER][pattern.RGB_BYTES]u8 = undefined;
    for (&patch, 0..) |*row, y| row.* = pattern.PATTERN[y + 1][1..][0..pattern.INNER].*;
    try paint(&client, display, 3, .{ .X = left + 1, .Y = pattern.TOP + 1, .Width = pattern.INNER, .Height = pattern.INNER }, std.mem.asBytes(&patch), protocol.PRESENTED);
    const outside = [_][pattern.RGB_BYTES]u8{pattern.INVALID} ** 2;
    try paint(&client, display, 4, .{ .X = mode.Width - 1, .Y = pattern.TOP, .Width = 2, .Height = 1 }, std.mem.asBytes(&outside), service.REFUSED);
    print.log(wire.PRESENTED_LINE, .{});
    verify.require(true, labels.PRESENTATION);
    try harness.advance(&client, 4);
}

fn paint(client: *const Actor, display: u64, step: usize, rectangle: Rectangle, pixels: []const u8, expected: u64) !void {
    var payload: [@sizeOf(Rectangle) + pattern.WIDTH * pattern.HEIGHT * pattern.RGB_BYTES]u8 = undefined;
    @memcpy(payload[0..@sizeOf(Rectangle)], std.mem.asBytes(&rectangle));
    @memcpy(payload[@sizeOf(Rectangle)..][0..pixels.len], pixels);
    const length = @sizeOf(Rectangle) + pixels.len;
    try harness.input(client, payload[0..length]);
    try harness.descriptorFor(client, display, protocol.PRESENT, length, 0);
    try harness.advance(client, step - 1);
    try expectReply(client, display, step, expected, 0);
}

fn expectReply(client: *const Actor, display: u64, step: usize, kind: u64, length: u64) !void {
    try harness.waitStep(client, step);
    const header = try harness.header(client);
    if (!try harness.resultIs(client, step, .Success, length) or header.Sender != display or
        header.Type != kind or header.Length != length or header.ReplyTicket != 0) return WitnessError.InvalidDisplayReply;
}
