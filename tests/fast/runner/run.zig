//! Native Guest Oracle Test Entry

const std = @import("std");

const fixtures = @import("tests").strings.oracle;
const labels = @import("tests").strings.scenario;
const result = @import("tests").runner.result;

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
