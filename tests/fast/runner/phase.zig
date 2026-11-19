//! Native Phase Ticket Regressions

const std = @import("std");

const fixtures = @import("tests").strings.oracle;
const inputs = @import("tests").constants.protocol;
const labels = @import("tests").strings.scenario;
const project = @import("tests");
const Scenario = @import("tests").types.scenario.Scenario;

pub fn actions() !void {
    const wire = project.phase.action;
    const Action = project.phase.types.action.Action;
    const epoch = 0x0807060504030201;
    const boot = [_]u8{ 'A', 'K', 'M', 'A', 1, 2, 3, 4, 5, 6, 7, 8, 1 };
    const stop = boot[0..12].* ++ [_]u8{2};
    const timeout = boot[0..12].* ++ [_]u8{3};
    const cancel = boot[0..12].* ++ [_]u8{4};
    try std.testing.expectEqualSlices(u8, &boot, &wire.encode(epoch, .Boot).?);
    try std.testing.expectEqual(@as(?Action, .Boot), wire.decode(&boot, epoch, .Menu));
    try std.testing.expectEqual(@as(?Action, .Shutdown), wire.decode(&stop, epoch, .Menu));
    try std.testing.expect(wire.decode(&timeout, epoch, .Menu) == null);
    try std.testing.expect(wire.encode(epoch, .Timeout) == null);
    try std.testing.expectEqual(@as(?Action, .Cancel), wire.decode(&cancel, epoch, .Testing));
    try std.testing.expect(wire.decode(&boot, epoch, .Testing) == null);
    try std.testing.expect(wire.decode(&stop, epoch, .Testing) == null);
    try std.testing.expect(wire.decode(&timeout, epoch, .Testing) == null);
    try std.testing.expect(wire.decode(&cancel, epoch, .Menu) == null);
    try std.testing.expect(wire.decode(&cancel, epoch, .Closed) == null);
    try std.testing.expect(wire.decode(&boot, epoch, .Closed) == null);
    try std.testing.expect(wire.decode(&boot, epoch + 1, .Menu) == null);
    try std.testing.expect(wire.decode(boot[0..12], epoch, .Menu) == null);
    try std.testing.expect(wire.encode(0, .Boot) == null);
    var malformed = boot;
    malformed[0] = 'S';
    try std.testing.expect(wire.decode(&malformed, epoch, .Menu) == null);
    malformed = boot;
    malformed[12] = 255;
    try std.testing.expect(wire.decode(&malformed, epoch, .Menu) == null);
}

pub fn menuCountdownFrame() !void {
    const menu = project.phase.menu;
    const epoch = 0x0807060504030201;
    const tick = [_]u8{ 'A', 'K', 'M', 'C', 1, 2, 3, 4, 5, 6, 7, 8, 29 };
    try std.testing.expectEqualSlices(u8, &tick, &menu.encodeCountdown(epoch, 29).?);
    try std.testing.expectEqual(@as(?u8, 29), menu.decodeCountdown(&tick, epoch, 30));
    try std.testing.expect(menu.decodeCountdown(&tick, epoch + 1, 30) == null);
    try std.testing.expect(menu.decodeCountdown(&tick, epoch, 29) == null);
    try std.testing.expect(menu.decodeCountdown(&tick, epoch, 28) == null);
    try std.testing.expect(menu.decodeCountdown(tick[0..12], epoch, 30) == null);
    try std.testing.expect(menu.encodeCountdown(0, 29) == null);
    for ([_]u8{ 0, 30, 255 }) |seconds| {
        var invalid = tick;
        invalid[12] = seconds;
        try std.testing.expect(menu.decodeCountdown(&invalid, epoch, 30) == null);
        try std.testing.expect(menu.encodeCountdown(epoch, seconds) == null);
    }
    var invalid = tick;
    invalid[3] = 'A';
    try std.testing.expect(menu.decodeCountdown(&invalid, epoch, 30) == null);
    @memset(invalid[4..12], 0);
    invalid[3] = 'C';
    try std.testing.expect(menu.decodeCountdown(&invalid, 0, 30) == null);
    const skipped = tick[0..12].* ++ [_]u8{7};
    try std.testing.expectEqual(@as(?u8, 7), menu.decodeCountdown(&skipped, epoch, 29));
}

pub fn menuIdleCountdown() !void {
    const transport = project.runner.phase;
    const network = project.runner.socket;
    const address = try std.net.Address.parseIp4(project.strings.protocol.ADDRESS, 0);
    var server = try address.listen(.{});
    defer server.deinit();
    const peer = idle: {
        const client = try network.startConnection(server.listen_address.getPort());
        defer client.close();
        const accepted = try server.accept();
        errdefer accepted.stream.close();
        try network.checkConnection(client);
        var timer = try std.time.Timer.start();
        try std.testing.expectEqual(.Timeout, try transport.menuAction(client, null, .{ .Timer = &timer, .Limit = 1200 * std.time.ns_per_ms }, null, 17));
        break :idle accepted.stream;
    };
    defer peer.close();
    const expected = [_]u8{ 'A', 'K', 'M', 'C', 17, 0, 0, 0, 0, 0, 0, 0, 1 };
    var bytes: [expected.len + 1]u8 = undefined;
    var received: usize = 0;
    while (received < bytes.len) {
        const count = try network.receive(peer.handle, bytes[received..]);
        if (count == 0) break;
        received += count;
    }
    try std.testing.expectEqualSlices(u8, &expected, bytes[0..received]);
}

pub fn menuFramePastCutoff() !void {
    const transport = project.runner.phase;
    const network = project.runner.socket;
    const address = try std.net.Address.parseIp4(project.strings.protocol.ADDRESS, 0);
    var server = try address.listen(.{});
    defer server.deinit();
    const client = try network.startConnection(server.listen_address.getPort());
    defer client.close();
    const peer = try server.accept();
    defer peer.stream.close();
    try network.checkConnection(client);
    const epoch = 17;
    const bytes = project.phase.action.encode(epoch, .Boot).?;
    try std.testing.expectEqual(@as(usize, 1), try network.send(peer.stream.handle, bytes[0..1]));
    const worker = try std.Thread.spawn(.{}, writeTail, .{ peer.stream.handle, bytes[1..] });
    defer worker.join();
    var timer = try std.time.Timer.start();
    const action = try transport.menuAction(client, null, .{ .Timer = &timer, .Limit = inputs.ACTION_IDLE_NS }, null, epoch);
    try std.testing.expectEqual(.Boot, action);
}

fn writeTail(handle: std.net.Stream.Handle, bytes: []const u8) void {
    std.Thread.sleep(inputs.ACTION_TAIL_DELAY_NS);
    var sent: usize = 0;
    while (sent < bytes.len) {
        const count = project.runner.socket.send(handle, bytes[sent..]) catch return;
        if (count == 0) return;
        sent += count;
    }
}

pub fn menuOffer() !void {
    const menu = project.phase.menu;
    const epoch = 0x0807060504030201;
    const expected = [_]u8{ 'A', 'K', 'M', 'V', 1, 2, 3, 4, 5, 6, 7, 8, 118, 7, 0, 0, '1', '9', '1', '1', '2', '0', '2', '6', 0, 0, 24, 0 };
    const offer: project.phase.types.menu.Offer = .{ .Epoch = epoch, .Passed = 1910, .Date = expected[16..24].*, .StandardCompleted = 24 };
    try std.testing.expectEqualSlices(u8, &expected, &menu.encodeOffer(offer).?);
    try std.testing.expectEqual(offer, menu.decodeOffer(&expected).?);
    try std.testing.expect(menu.decodeOffer(expected[0..23]) == null);
    try std.testing.expect(menu.encodeOffer(.{ .Epoch = epoch, .Passed = 0, .Date = offer.Date, .StandardCompleted = 24 }) == null);
    var invalid = expected;
    invalid[16] = '9';
    try std.testing.expect(menu.decodeOffer(&invalid) == null);
    const armed = [_]u8{ 'A', 'K', 'M', 'E', 1, 2, 3, 4, 5, 6, 7, 8 };
    try std.testing.expectEqualSlices(u8, &armed, &menu.encodeArmed(epoch));
    try std.testing.expect(menu.isArmed(epoch, &armed));
    try std.testing.expect(!menu.isArmed(epoch + 1, &armed));
    try std.testing.expect(!menu.isArmed(epoch, &expected));
}

pub fn failedMenuOffer() !void {
    const menu = project.phase.menu;
    const Offer = project.phase.types.menu.Offer;
    const wire = [_]u8{ 'A', 'K', 'M', 'V', 1, 0, 0, 0, 0, 0, 0, 0, 115, 7, 0, 0, '1', '9', '1', '1', '2', '0', '2', '6', 1, 1, 0, 0 };
    const failure: Offer = menu.decodeOffer(&wire).?;
    try std.testing.expectEqual(@as(u32, 1907), failure.Passed);
    try std.testing.expectEqual(@as(u8, 1), failure.FailedMask);
    try std.testing.expectEqual(@as(u8, 1), failure.InterruptedMask);
    try std.testing.expectEqualSlices(u8, &wire, &menu.encodeOffer(failure).?);
    try std.testing.expectEqual(@as(usize, 4), menu.completedUnits(failure));
    var refused = failure;
    refused.InterruptedMask = 2;
    try std.testing.expect(menu.encodeOffer(refused) == null);
    refused = failure;
    refused.FailedMask = 32;
    try std.testing.expect(menu.encodeOffer(refused) == null);
    refused = failure;
    refused.FailedMask = 31;
    try std.testing.expect(menu.encodeOffer(refused) == null);
    refused.Passed = 0;
    try std.testing.expect(menu.encodeOffer(refused) != null);
}

pub fn namedMenuPhases() !void {
    const menu = project.phase.menu;
    const device = [_]u8{ 'A', 'K', 'M', 'V', 1, 0, 0, 0, 0, 0, 0, 0, 115, 7, 0, 0, '1', '9', '1', '1', '2', '0', '2', '6', 8, 8, 24, 0 };
    var offer = menu.decodeOffer(&device) orelse return error.NamedMenuPhaseUnavailable;
    try std.testing.expectEqual(@as(u32, 1907), offer.Passed);
    try std.testing.expectEqual(.Incomplete, menu.phaseStatus(offer, .Devices));
    try std.testing.expectEqual(.Passed, menu.phaseStatus(offer, .Firmware));
    try std.testing.expectEqual(.Passed, menu.phaseStatus(offer, .Collapse));
    offer.InterruptedMask = 0;
    try std.testing.expectEqual(.Failed, menu.phaseStatus(offer, .Devices));
    try std.testing.expectEqual(@as(usize, 28), menu.completedUnits(offer));
    offer.InterruptedMask = 4;
    try std.testing.expect(menu.encodeOffer(offer) == null);
}

pub fn liveHistory() !void {
    const live = project.phase.live;
    const view = project.screen.live;
    const model = project.screen.model;
    const packet = [_]u8{ 'A', 'K', 'L', 'P', 17, 0, 0, 0, 0, 0, 0, 0, 3, 2, 2, 24, 0, 113, 7, 0, 0, '1', '9', '1', '1', '2', '0', '2', '6' };
    const offer = live.decodeOffer(&packet).?;
    try std.testing.expectEqual(.Devices, offer.Ticket.Scenario);
    try std.testing.expectEqualSlices(u8, &packet, &live.encodeOffer(offer).?);
    const acknowledgement = [_]u8{ 'A', 'K', 'L', 'A', 17, 0, 0, 0, 0, 0, 0, 0, 3 };
    try std.testing.expectEqualSlices(u8, &acknowledgement, &live.encodeAcknowledgement(offer.Ticket));
    try std.testing.expect(!live.acknowledges(.{ .Epoch = 16, .Scenario = .Devices }, &acknowledgement));
    var forged = offer;
    forged.FailedMask = 8;
    try std.testing.expect(live.encodeOffer(forged) == null);
    forged = offer;
    forged.StandardCompleted = 23;
    try std.testing.expect(live.encodeOffer(forged) == null);
    var rows: [32]project.screen.types.model.Row = undefined;
    var state = view.initialize(&rows, offer);
    try std.testing.expectEqual(@as(usize, 28), state.Total);
    try std.testing.expectEqual(@as(usize, 25), state.Completed);
    try std.testing.expectEqual(.Pass, model.row(&state, 1).?.Kind);
    try std.testing.expectEqualStrings(fixtures.RESTORED_BOOTSTRAP, model.row(&state, 1).?.Text);
    try std.testing.expectEqualStrings(fixtures.RESTORED_CRIMSON, model.row(&state, 24).?.Text);
    try std.testing.expectEqual(.Fail, model.row(&state, 26).?.Kind);
    try std.testing.expectEqualStrings(fixtures.INCOMPLETE_PULSE, model.row(&state, 26).?.Text);
    try std.testing.expectEqual(.Pass, model.row(&state, 27).?.Kind);
    try std.testing.expect(model.begin(&state, view.name(.Devices)));
    try std.testing.expectEqual(.Running, model.row(&state, state.Count).?.Kind);
    try std.testing.expectEqual(@as(usize, 89), model.percent(&state));
    try std.testing.expect(model.finish(&state, .Pass));
    try std.testing.expect(model.endPhase(&state));
    try std.testing.expectEqual(@as(usize, 26), state.Completed);

    var partial = offer;
    partial.FailedMask = 3;
    partial.InterruptedMask = 3;
    partial.StandardCompleted = 3;
    partial.VerifiedChecks = 75;
    try std.testing.expect(live.encodeOffer(partial) != null);
    state = view.initialize(&rows, partial);
    try std.testing.expectEqual(@as(usize, 4), state.Completed);
    try std.testing.expectEqual(.Pass, model.row(&state, 3).?.Kind);
    try std.testing.expectEqualStrings(fixtures.INCOMPLETE_STANDARD, model.row(&state, 4).?.Text);
    try std.testing.expectEqual(.Fail, model.row(&state, 4).?.Kind);
    try std.testing.expect(model.row(&state, 7) == null);
}

pub fn earlyFailures() !void {
    const result = project.runner.result;
    try std.testing.expect(result.failedBeforeSelection(fixtures.FAIL));
    try std.testing.expect(result.failedBeforeSelection(labels.PANIC));
    try std.testing.expect(result.failedBeforeSelection(fixtures.COLLAPSE_VALID));
    try std.testing.expect(!result.failedBeforeSelection(fixtures.VALID));
    try std.testing.expect(!result.failedBeforeSelection(fixtures.PENDING));
}

pub fn greeting() !void {
    const wire = project.phase.wire;
    const ready = project.phase.constants.wire.READY;
    const prelude = [_]u8{ 0x1b, '[', '2', 'J', 'A', 'K', 'P', 'R', 0x0d, 0x0a };
    var matched: usize = 0;
    for (prelude) |byte| matched = wire.advanceGreeting(&ready, matched, byte);
    try std.testing.expectEqual(@as(usize, 0), matched);
    for (ready[0..3]) |byte| matched = wire.advanceGreeting(&ready, matched, byte);
    try std.testing.expectEqual(@as(usize, 3), matched);
    for (ready, 0..) |byte, index| {
        matched = wire.advanceGreeting(&ready, matched, byte);
        try std.testing.expectEqual(index + 1, matched);
    }
}

pub fn frames() !void {
    const wire = project.phase.wire;
    const Ticket = project.phase.types.ticket.Ticket;
    const sample: Ticket = .{ .Epoch = 0x0807060504030201, .Scenario = .Devices };
    const expected = [_]u8{ 'A', 'K', 'P', 'T', 1, 2, 3, 4, 5, 6, 7, 8, 3 };
    const packet = wire.encode(sample, .Offer).?;
    try std.testing.expectEqualSlices(u8, &expected, &packet);
    for ([_]Scenario{ .Standard, .PulseDeath, .Devices, .Collapse }) |scenario| {
        const ticket: Ticket = .{ .Epoch = sample.Epoch, .Scenario = scenario };
        const encoded = wire.encode(ticket, .Offer).?;
        try std.testing.expectEqual(ticket, wire.decode(&encoded, .Offer).?);
    }
    try std.testing.expect(wire.encode(.{ .Epoch = 0, .Scenario = .Standard }, .Offer) == null);
    try std.testing.expect(wire.encode(.{ .Epoch = sample.Epoch, .Scenario = .Firmware }, .Offer) == null);
}

pub fn acknowledgements() !void {
    const wire = project.phase.wire;
    const Ticket = project.phase.types.ticket.Ticket;
    const expected: Ticket = .{ .Epoch = 17, .Scenario = .PulseDeath };
    const accepted = wire.encode(expected, .Acknowledgement).?;
    try std.testing.expect(wire.acknowledges(expected, &accepted));
    try std.testing.expect(!wire.acknowledges(expected, accepted[0 .. accepted.len - 1]));
    try std.testing.expect(wire.decode(&accepted, .Offer) == null);
    const wrong_role = wire.encode(expected, .Offer).?;
    try std.testing.expect(!wire.acknowledges(expected, &wrong_role));
    const stale = wire.encode(.{ .Epoch = 16, .Scenario = .PulseDeath }, .Acknowledgement).?;
    try std.testing.expect(!wire.acknowledges(expected, &stale));
    const wrong_phase = wire.encode(.{ .Epoch = 17, .Scenario = .Standard }, .Acknowledgement).?;
    try std.testing.expect(!wire.acknowledges(expected, &wrong_phase));
    var malformed = accepted;
    malformed[malformed.len - 1] = 255;
    try std.testing.expect(!wire.acknowledges(expected, &malformed));
    malformed = accepted;
    @memset(malformed[4..12], 0);
    try std.testing.expect(wire.decode(&malformed, .Acknowledgement) == null);
}
