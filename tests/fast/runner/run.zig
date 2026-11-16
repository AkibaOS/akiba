//! Native Guest Oracle Test Entry

const std = @import("std");

const fixtures = @import("tests").strings.oracle;
const labels = @import("tests").strings.scenario;
const peer = @import("tests").fast.runner.protocol;
const result = @import("tests").runner.result;

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
