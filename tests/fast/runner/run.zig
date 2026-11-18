//! Native Guest Oracle Test Entry

const std = @import("std");

const fixtures = @import("tests").strings.oracle;
const input = @import("tests").types.input;
const labels = @import("tests").strings.scenario;
const phase = @import("tests").fast.runner.phase;
const peer = @import("tests").fast.runner.protocol;
const result = @import("tests").runner.result;
const runner = @import("tests").runner;
const Epoch = @import("tests").types.host.Epoch;

test "serial evidence starts at the new boot boundary and rejects truncation" {
    var directory = std.testing.tmpDir(.{});
    defer directory.cleanup();
    var file = try directory.dir.createFile(fixtures.SERIAL_FILE, .{ .read = true });
    defer file.close();
    try file.writeAll(fixtures.VALID);
    const start = try file.getEndPos();
    try file.writeAll(fixtures.PENDING);
    const epoch: Epoch = .{ .File = &file, .Start = start };
    const evidence = try runner.serial.read(std.testing.allocator, epoch);
    defer std.testing.allocator.free(evidence);
    try std.testing.expectEqualStrings(fixtures.PENDING, evidence);
    try std.testing.expectEqual(@as(?usize, null), try result.evaluate(evidence, .Standard));
    try file.setEndPos(0);
    try std.testing.expectError(error.SerialHistoryLost, runner.serial.read(std.testing.allocator, epoch));
}

test "input challenge rejects prior and unsolicited IRQ evidence" {
    const ready = fixtures.INPUT_READY;
    const make = fixtures.INPUT_MAKE;
    const release = fixtures.INPUT_BREAK;
    var challenge: input.Challenge = .{ .Keys = &.{.{ .Name = fixtures.KEY, .Make = 0x30 }} };
    try std.testing.expectError(error.MissingInjectedInput, runner.input.observe(&challenge, ready ++ fixtures.VALID));
    challenge = .{ .Keys = challenge.Keys };
    try std.testing.expectError(error.UnexpectedKeyboardInput, runner.input.observe(&challenge, ready ++ make ++ release));
    challenge = .{ .Keys = challenge.Keys };
    try std.testing.expectEqual(.Waiting, try runner.input.observe(&challenge, make ++ fixtures.INPUT_READY_PARTIAL));
    try std.testing.expectEqual(.Inject, try runner.input.observe(&challenge, make ++ ready));
    runner.input.sent(&challenge);
    try std.testing.expectError(error.UnexpectedKeyboardInput, runner.input.observe(&challenge, make ++ ready ++ release));
    challenge = .{ .Keys = challenge.Keys };
    try std.testing.expectEqual(.Inject, try runner.input.observe(&challenge, ready));
    runner.input.sent(&challenge);
    try std.testing.expectEqual(.Waiting, try runner.input.observe(&challenge, ready ++ make));
    try std.testing.expectEqual(.Complete, try runner.input.observe(&challenge, ready ++ make ++ release));
    try std.testing.expectEqual(.Waiting, try runner.input.observe(&challenge, ready ++ make ++ release ++ fixtures.INPUT_PARTIAL_IRQ));
    try std.testing.expectError(error.UnexpectedKeyboardInput, runner.input.observe(&challenge, ready ++ make ++ release ++ make));
}

test "snapshot job must conclude successfully and belong to this session" {
    const pending = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, fixtures.SNAPSHOT_PENDING, .{});
    defer pending.deinit();
    const complete = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, fixtures.SNAPSHOT_COMPLETE, .{});
    defer complete.deinit();
    const failed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, fixtures.SNAPSHOT_FAILED, .{});
    defer failed.deinit();
    try std.testing.expect(!try runner.checkpoint.concluded(pending.value, fixtures.SNAPSHOT_ID));
    try std.testing.expect(try runner.checkpoint.concluded(complete.value, fixtures.SNAPSHOT_ID));
    try std.testing.expectError(error.SnapshotJobLost, runner.checkpoint.concluded(complete.value, fixtures.OTHER_JOB));
    try std.testing.expectError(error.SnapshotJobFailed, runner.checkpoint.concluded(failed.value, fixtures.SNAPSHOT_ID));
}

test "QMP loopback refuses a guest reset before accepting a command reply" {
    try peer.rejects(.Reset, error.UnexpectedGuestEvent);
}

test "QMP quit accepts peer closure after request but refuses explicit errors" {
    try peer.accepts(.QuitClosed);
    try peer.rejects(.QuitRefused, error.QmpCommandFailed);
}

test "QMP keeps the outstanding reply across a short socket timeout" {
    try peer.accepts(.LateReply);
}

test "QMP verification refuses an explicitly headless display" {
    try peer.rejects(.Headless, error.MissingQemuWindow);
}

test "phase frames encode four Mirai choices with an explicit nonzero epoch" {
    try phase.frames();
}

test "phase acknowledgements reject wrong roles epochs and phase choices" {
    try phase.acknowledgements();
}

test "phase greeting recognizes the binary marker after firmware console bytes" {
    try phase.greeting();
}

test "pre-ticket evidence detects failures without accepting a guest outcome" {
    try phase.earlyFailures();
}

test "QMP loopback rejects invalid greetings" {
    try peer.rejects(.InvalidGreeting, error.QmpInvalidGreeting);
}

test "QMP loopback propagates explicit command errors" {
    try peer.rejects(.ErrorReply, error.QmpCommandFailed);
}

test "QMP loopback ignores events and unrelated sequence IDs" {
    try peer.events();
}

test "QMP ownership verification rejects a differently named guest" {
    try peer.rejects(.WrongName, error.WrongGuest);
}

test "QMP loopback reports an orderly disconnected peer" {
    try peer.rejects(.Disconnect, error.QmpDisconnected);
}

test "QMP slow-byte peer cannot renew the overall operation deadline" {
    try peer.deadline();
}

test "Crimson collapse oracle requires its selected checkpoint exact reason and halt" {
    try std.testing.expectEqual(@as(?usize, 1), try result.evaluate(fixtures.COLLAPSE_VALID, .Collapse));
}

test "Crimson collapse oracle rejects an unarmed or differently caused collapse" {
    try std.testing.expectError(error.UnexpectedFatalOutcome, result.evaluate(fixtures.COLLAPSE_UNARMED, .Collapse));
    try std.testing.expectError(error.UnexpectedFatalOutcome, result.evaluate(fixtures.COLLAPSE_WRONG, .Collapse));
}

test "unexpected Crimson collapse fails normal and other fatal scenarios" {
    try std.testing.expectError(error.GuestCheckFailed, result.evaluate(fixtures.COLLAPSE_VALID, .Standard));
    try std.testing.expectError(error.UnexpectedFatalOutcome, result.evaluate(fixtures.COLLAPSE_VALID, .PulseDeath));
}

test "firmware oracle accepts its own nonempty completion without kernel ready" {
    try std.testing.expectEqual(@as(?usize, 8), try result.evaluate(fixtures.FIRMWARE_VALID, .Firmware));
}

test "firmware oracle rejects standard output and an empty firmware run" {
    try std.testing.expectError(error.UnexpectedFirmwareOutcome, result.evaluate(fixtures.VALID, .Firmware));
    try std.testing.expectError(error.IncompleteGuestChecks, result.evaluate(fixtures.FIRMWARE_EMPTY, .Firmware));
    try std.testing.expectError(error.GuestCheckFailed, result.evaluate(fixtures.FIRMWARE_VALID ++ fixtures.PANIC, .Firmware));
}

test "serial oracle accepts completed nonempty standard checks" {
    try std.testing.expectEqual(@as(?usize, 1), try result.evaluate(fixtures.VALID, .Standard));
}

test "serial oracle waits for readiness without inventing a pass" {
    try std.testing.expectEqual(@as(?usize, null), try result.evaluate(fixtures.PENDING, .Standard));
}

test "serial oracle rejects readiness without test begin or completion" {
    try std.testing.expectError(error.MissingGuestChecks, result.evaluate(fixtures.MISSING, .Standard));
    try std.testing.expectError(error.IncompleteGuestChecks, result.evaluate(fixtures.INCOMPLETE, .Standard));
}

test "serial oracle rejects zero mismatched and malformed assertion counts" {
    try std.testing.expectError(error.IncompleteGuestChecks, result.evaluate(fixtures.ZERO, .Standard));
    try std.testing.expectError(error.IncompleteGuestChecks, result.evaluate(fixtures.MISMATCH, .Standard));
    try std.testing.expectError(error.InvalidCharacter, result.evaluate(fixtures.BAD_COUNT, .Standard));
}

test "serial oracle rejects failed assertions and unexpected panics" {
    try std.testing.expectError(error.GuestCheckFailed, result.evaluate(fixtures.FAIL, .Standard));
    try std.testing.expectError(error.GuestCheckFailed, result.evaluate(fixtures.PANIC, .Standard));
    try std.testing.expectError(error.GuestCheckFailed, result.evaluate(fixtures.VALID ++ fixtures.PANIC, .Standard));
}

test "fatal oracle requires its exact panic after its checkpoint" {
    try std.testing.expectEqual(@as(?usize, 1), try result.evaluate(fixtures.BEGIN ++ labels.CHECKPOINT ++ labels.PANIC, .PulseDeath));
}

test "fatal oracle accepts UART carriage return line endings" {
    try std.testing.expectEqual(@as(?usize, 1), try result.evaluate(fixtures.FATAL_CRLF, .PulseDeath));
}

test "fatal oracle rejects missing reversed or wrong fatal evidence" {
    try std.testing.expectError(error.UnexpectedFatalOutcome, result.evaluate(labels.PANIC, .PulseDeath));
    try std.testing.expectError(error.UnexpectedFatalOutcome, result.evaluate(fixtures.BEGIN ++ labels.PANIC ++ labels.CHECKPOINT, .PulseDeath));
    try std.testing.expectError(error.UnexpectedFatalOutcome, result.evaluate(fixtures.BEGIN ++ labels.CHECKPOINT ++ fixtures.PANIC, .PulseDeath));
}

test "fatal oracle never accepts a normal ready result or a check failure" {
    try std.testing.expectError(error.UnexpectedFatalOutcome, result.evaluate(fixtures.VALID, .PulseDeath));
    try std.testing.expectError(error.GuestCheckFailed, result.evaluate(fixtures.BEGIN ++ labels.CHECKPOINT ++ fixtures.FAIL ++ labels.PANIC, .PulseDeath));
    try std.testing.expectEqual(@as(?usize, null), try result.evaluate(fixtures.BEGIN ++ labels.CHECKPOINT, .PulseDeath));
}
