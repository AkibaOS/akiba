//! Draw And Refuse Real Display Requests Before Native Scanout Verification

const std = @import("std");

const copy = @import("mirai").user.copy.transfer;
const fixture = @import("tests").guest.constants.ahci.fixture;
const harness = @import("tests").guest.postman.harness;
const instances = @import("mirai").device.instance.registry;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.drivers.input;
const locations = @import("tests").guest.constants.postman.transport;
const locators = @import("mirai").device.constants.instance.limits;
const pattern = @import("tests").phase.constants.display;
const print = @import("mirai").boot.sequence.print;
const protocol = @import("shared").display.constants.postman;
const screen = @import("tests").guest.screen.control;
const sensei = @import("mirai").sensei;
const service = @import("shared").pulse.constants.supervision.protocol;
const timing = @import("tests").fixtures.constants.service;
const verify = @import("tests").guest.support.verify;
const wire = @import("tests").phase.strings.display;

const Actor = @import("tests").guest.types.postman.fixtures.Actor;
const DeviceOperation = @import("shared").device.types.operation.Operation;
const Mode = @import("shared").display.types.mode.Mode;
const Operation = @import("tests").guest.types.postman.fixtures.Operation;
const Rectangle = @import("shared").display.types.rectangle.Rectangle;
const Row = @import("shared").display.types.row.Row;
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
    try harness.install(&client, &([_]Operation{harness.call(&client)} ** 7));
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
    try rebind(&client, display, mode, left);
    print.log(wire.PRESENTED_LINE, .{});
    verify.require(true, labels.PRESENTATION);
    try harness.advance(&client, 7);
}

fn rebind(client: *const Actor, display: u64, mode: Mode, left: u32) !void {
    const original = kata.state.findByID(display) orelse return WitnessError.DisplayDriverMissing;
    const previous = instances.handleFor(original) orelse return WitnessError.DisplayDriverMissing;
    const device = instances.find(.Framebuffer, locators.FIRMWARE_SURFACE) orelse return WitnessError.DisplayDriverMissing;
    try harness.descriptorFor(client, display, service.SERVICE_STOP, 0, 0);
    try harness.advance(client, 4);
    try expectReply(client, display, 5, service.SERVICE_STOPPED, 0);
    const until = sensei.state.getState().Ticks + timing.RECOVERY_TICKS;
    while (sensei.state.getState().Ticks < until) {
        if (instances.assignedOwner(device)) |replacement| {
            if (replacement.ID != display) {
                const handle = instances.handleFor(replacement) orelse return WitnessError.DisplayDriverMissing;
                try harness.descriptorFor(client, replacement.ID, service.SERVICE_QUERY, 0, 0);
                try harness.advance(client, 5);
                try expectReply(client, replacement.ID, 6, service.SERVICE_READY, 0);
                try stale(replacement.ID, previous, handle, mode, left);
                const background = [_]u8{ pattern.BACKGROUND[0], pattern.BACKGROUND[1], pattern.BACKGROUND[2] };
                try paint(client, replacement.ID, 7, .{ .X = left, .Y = pattern.TOP, .Width = 1, .Height = 1 }, &background, protocol.PRESENTED);
                verify.require(handle != previous and kata.completion.storage.ownerOf(replacement.ID) == client.ID, labels.REBOUND_SURFACE);
                return;
            }
        }
        try sensei.run.yield();
    }
    verify.require(false, labels.REBOUND_SURFACE);
}

fn stale(identifier: u64, previous: u64, handle: u64, mode: Mode, left: u32) !void {
    const owner = kata.state.findByID(identifier) orelse return WitnessError.DisplayDriverMissing;
    var caller = try harness.attach(.{ .Owner = owner, .ID = identifier, .Code = fixture.DISPLAY_CODE, .Data = fixture.DISPLAY_DATA, .Stack = fixture.DISPLAY_STACK });
    const pixel = @as(u32, pattern.BACKGROUND[0]) << 16 | @as(u32, pattern.BACKGROUND[1]) << 8 | pattern.BACKGROUND[2];
    const color = if (mode.Format == .RGB) @byteSwap(pixel) >> 8 else pixel;
    try copy.write(owner, caller.Data + locations.OUTPUT_OFFSET, std.mem.asBytes(&color));
    const row: Row = .{ .X = left, .Y = pattern.TOP, .Width = 1, .Pixels = caller.Data + locations.OUTPUT_OFFSET };
    try harness.input(&caller, std.mem.asBytes(&row));
    var operation: Operation = .{ .Service = .Device, .First = .{ .Immediate = @intFromEnum(DeviceOperation.SurfaceRow) }, .Second = previous, .Third = caller.Data + locations.INPUT_OFFSET };
    const invalid = operation;
    operation.Second = handle;
    try harness.install(&caller, &.{ invalid, operation });
    try harness.start(&caller);
    try harness.waitStep(&caller, 1);
    const denied = try harness.resultIs(&caller, 1, .InvalidCaller, 0);
    try harness.advance(&caller, 1);
    try harness.waitStep(&caller, 2);
    verify.require(denied and try harness.resultIs(&caller, 2, .Success, 0), labels.STALE_SURFACE);
    try harness.advance(&caller, 2);
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
