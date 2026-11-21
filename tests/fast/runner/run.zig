//! Native Guest Oracle Test Entry

const std = @import("std");

const boot = @import("tests").phase.boot;
const fixtures = @import("tests").fast.runner.strings.oracle;
const input = @import("tests").runner.types.input;
const labels = @import("tests").phase.strings.scenario;
const phase = @import("tests").fast.runner.phase;
const peer = @import("tests").fast.runner.protocol;
const result = @import("tests").runner.report.result;
const runner = @import("tests").runner;
const Epoch = @import("tests").runner.types.host.Epoch;
const Scenario = @import("tests").phase.types.scenario.Scenario;
const Selection = @import("tests").phase.types.boot.frame.Selection;

test "AHCI evidence requires the installed Pulse to run in Persona" {
    const primary = fixtures.AHCI_HEADER;
    const volume = fixtures.AHCI_VOLUME;
    const location = fixtures.AHCI_LOCATION;
    const image = fixtures.AHCI_IMAGE;
    const pulse = fixtures.AHCI_PULSE;
    const lf = fixtures.LF;
    const crlf = fixtures.CRLF;
    const prefix = primary ++ lf ++ volume ++ lf ++ location ++ lf;
    const bytes = prefix ++ image ++ lf;
    const suffix = image ++ lf ++ pulse ++ lf;
    try result.verifyAhci(bytes ++ pulse ++ lf);
    try result.verifyAhci(primary ++ crlf ++ volume ++ crlf ++ location ++ crlf ++ image ++ crlf ++ pulse ++ crlf);
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(bytes));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(prefix ++ pulse ++ lf));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(primary ++ lf ++ volume ++ lf ++ suffix));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(primary ++ lf ++ location ++ lf ++ suffix));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(volume ++ lf ++ location ++ lf ++ suffix));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(volume ++ lf ++ primary ++ lf ++ location ++ lf ++ suffix));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(primary ++ lf ++ location ++ lf ++ volume ++ lf ++ suffix));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(image ++ lf ++ prefix ++ pulse ++ lf));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(prefix ++ pulse ++ lf ++ image ++ lf));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(bytes ++ fixtures.AHCI_PREFIX ++ pulse ++ lf));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(bytes ++ pulse ++ crlf ++ pulse ++ lf));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(primary ++ crlf ++ bytes ++ pulse ++ lf));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(volume ++ crlf ++ bytes ++ pulse ++ lf));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(prefix ++ location ++ crlf ++ suffix));
    try std.testing.expectError(error.MissingAhciEvidence, result.verifyAhci(bytes ++ image ++ crlf ++ pulse ++ lf));
}

test "a boot selector acknowledgement binds the exact role and epoch" {
    const selection: Selection = .{ .Epoch = 0x0807060504030201, .Role = .Menu };
    const encoded = [_]u8{ 'A', 'K', 'B', 'O', 1, 2, 3, 4, 5, 6, 7, 8, 2 };
    try std.testing.expectEqualSlices(u8, &encoded, &boot.encode(selection, .Offer).?);
    try std.testing.expectEqual(selection, boot.decode(&encoded, .Offer).?);
    try std.testing.expect(boot.decode(encoded[0..12], .Offer) == null);
    try std.testing.expect(boot.decode(&encoded, .Acknowledgement) == null);
    var corrupt = encoded;
    corrupt[12] = 4;
    try std.testing.expect(boot.decode(&corrupt, .Offer) == null);
    @memset(corrupt[4..12], 0);
    corrupt[12] = 2;
    try std.testing.expect(boot.decode(&corrupt, .Offer) == null);
    const acknowledged = boot.encode(selection, .Acknowledgement).?;
    try std.testing.expect(boot.acknowledges(selection, &acknowledged));
    try std.testing.expect(!boot.acknowledges(.{ .Epoch = selection.Epoch + 1, .Role = .Menu }, &acknowledged));
    try std.testing.expect(!boot.acknowledges(.{ .Epoch = selection.Epoch, .Role = .Ordinary }, &acknowledged));
}

test "diagnostic build date uses the cached image timestamp in UTC" {
    try phase.buildDate();
}

test "serial evidence starts at the new boot boundary and rejects truncation" {
    var directory = std.testing.tmpDir(.{});
    defer directory.cleanup();
    var file = try directory.dir.createFile(fixtures.SERIAL_FILE, .{ .read = true });
    defer file.close();
    try file.writeAll(fixtures.VALID);
    const start = try file.getEndPos();
    try file.writeAll(fixtures.PENDING);
    const epoch: Epoch = .{ .File = &file, .Start = start };
    const evidence = try runner.transport.serial.read(std.testing.allocator, epoch);
    defer std.testing.allocator.free(evidence);
    try std.testing.expectEqualStrings(fixtures.PENDING, evidence);
    try std.testing.expectEqual(@as(?usize, null), try result.evaluate(evidence, .Standard));
    try file.setEndPos(0);
    try std.testing.expectError(error.SerialHistoryLost, runner.transport.serial.read(std.testing.allocator, epoch));
}

test "input challenge rejects prior and unsolicited IRQ evidence" {
    const ready = fixtures.INPUT_READY;
    const make = fixtures.INPUT_MAKE;
    const release = fixtures.INPUT_BREAK;
    var challenge: input.Challenge = .{ .Keys = &.{.{ .Name = fixtures.KEY, .Make = 0x30 }} };
    try std.testing.expectError(error.MissingInjectedInput, runner.session.input.observe(&challenge, ready ++ fixtures.VALID));
    challenge = .{ .Keys = challenge.Keys };
    try std.testing.expectError(error.UnexpectedKeyboardInput, runner.session.input.observe(&challenge, ready ++ make ++ release));
    challenge = .{ .Keys = challenge.Keys };
    try std.testing.expectEqual(.Waiting, try runner.session.input.observe(&challenge, make ++ fixtures.INPUT_READY_PARTIAL));
    try std.testing.expectEqual(.Inject, try runner.session.input.observe(&challenge, make ++ ready));
    runner.session.input.sent(&challenge);
    try std.testing.expectError(error.UnexpectedKeyboardInput, runner.session.input.observe(&challenge, make ++ ready ++ release));
    challenge = .{ .Keys = challenge.Keys };
    try std.testing.expectEqual(.Inject, try runner.session.input.observe(&challenge, ready));
    runner.session.input.sent(&challenge);
    try std.testing.expectEqual(.Waiting, try runner.session.input.observe(&challenge, ready ++ make));
    try std.testing.expectEqual(.Complete, try runner.session.input.observe(&challenge, ready ++ make ++ release));
    try std.testing.expectEqual(.Waiting, try runner.session.input.observe(&challenge, ready ++ make ++ release ++ fixtures.INPUT_PARTIAL_IRQ));
    try std.testing.expectError(error.UnexpectedKeyboardInput, runner.session.input.observe(&challenge, ready ++ make ++ release ++ make));
}

test "snapshot job must conclude successfully and belong to this session" {
    const pending = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, fixtures.SNAPSHOT_PENDING, .{});
    defer pending.deinit();
    const complete = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, fixtures.SNAPSHOT_COMPLETE, .{});
    defer complete.deinit();
    const failed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, fixtures.SNAPSHOT_FAILED, .{});
    defer failed.deinit();
    try std.testing.expect(!try runner.machine.checkpoint.concluded(pending.value, fixtures.SNAPSHOT_ID));
    try std.testing.expect(try runner.machine.checkpoint.concluded(complete.value, fixtures.SNAPSHOT_ID));
    try std.testing.expectError(error.SnapshotJobLost, runner.machine.checkpoint.concluded(complete.value, fixtures.OTHER_JOB));
    try std.testing.expectError(error.SnapshotJobFailed, runner.machine.checkpoint.concluded(failed.value, fixtures.SNAPSHOT_ID));
}

test "only failures local to a test phase can proceed to cold recovery" {
    try std.testing.expect(runner.session.recovery.local(.Select, error.GuestPhaseTimeout));
    try std.testing.expect(runner.session.recovery.local(.Checks, error.GuestCheckTimeout));
    try std.testing.expect(runner.session.recovery.local(.Checks, error.UnexpectedKeyboardInput));
    try std.testing.expect(runner.session.recovery.local(.Checks, error.UnexpectedFatalOutcome));
    try std.testing.expect(!runner.session.recovery.local(.Restore, error.GuestPhaseTimeout));
    try std.testing.expect(!runner.session.recovery.local(.Menu, error.GuestCheckFailed));
    try std.testing.expect(!runner.session.recovery.local(.Select, error.InvalidPhaseAcknowledgement));
    try std.testing.expect(!runner.session.recovery.local(.Checks, error.UnexpectedGuestEvent));
    try std.testing.expect(!runner.session.recovery.local(.Checks, error.GuestExited));
    try std.testing.expect(!runner.session.recovery.local(.Checks, error.Cancelled));
}

test "QMP recovery requires a verified pause and rejects a reset" {
    try peer.accepts(.RecoverRunning);
    try peer.accepts(.RecoverPaused);
    try peer.rejects(.RecoverReset, error.UnexpectedGuestEvent);
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

test "session controls reject stale epochs and actions inappropriate to the active screen" {
    try phase.actions();
}

test "final menu identifies the incomplete phase rather than guessing from counts" {
    try phase.namedMenuPhases();
}

test "failed menu summary separates interrupted and failed phases" {
    try phase.failedMenuOffer();
}

test "menu requires the current arm acknowledgement and the verified suite summary" {
    try phase.menuOffer();
}

test "menu countdown rejects stale, malformed and nondecreasing ticks" {
    try phase.menuCountdownFrame();
}

test "idle menu sends only changed seconds before timing out without an acknowledgement" {
    try phase.menuIdleCountdown();
}

test "menu command that starts before cutoff can finish with bounded grace" {
    try phase.menuFramePastCutoff();
}

test "ordinary exit rejects a panic after verified readiness" {
    try peer.rejects(.OrdinaryPanic, error.NormalBootFailed);
}

test "ordinary exit accepts an operator close but not a guest reset" {
    try peer.accepts(.OperatorClosed);
    try peer.accepts(.OperatorQuit);
    try peer.rejects(.ResetToShutdown, error.UnexpectedGuestEvent);
}

test "cancellation preserves partial checks without admitting a completed verdict" {
    try std.testing.expectEqual(@as(usize, 0), try result.cancelledCount(fixtures.CANCELLED_EMPTY));
    try std.testing.expectEqual(@as(usize, 1), try result.cancelledCount(fixtures.CANCELLED_ONE));
    try std.testing.expectEqual(@as(usize, 1), try result.cancelledCount(fixtures.FIRMWARE_CANCELLED_ONE));
    try std.testing.expectError(error.InvalidCancellationEvidence, result.cancelledCount(fixtures.FIRMWARE_VALID ++ fixtures.CANCELLED_EIGHT));
    try std.testing.expectError(error.InvalidCancellationEvidence, result.cancelledCount(fixtures.CANCELLED_MISMATCH));
    try std.testing.expectError(error.InvalidCancellationEvidence, result.cancelledCount(fixtures.CANCELLED_INCOMPLETE));
    try std.testing.expectError(error.InvalidCancellationEvidence, result.cancelledCount(fixtures.CANCELLED_EMPTY ++ fixtures.CANCELLED_EMPTY));
    try std.testing.expectError(error.InvalidCancellationEvidence, result.cancelledCount(fixtures.CANCELLED_ONE ++ fixtures.VALID));
}

test "ordinary handoff refuses diagnostic output even with a ready marker" {
    try std.testing.expect(try result.ordinaryReady(fixtures.MISSING));
    try std.testing.expect(!try result.ordinaryReady(""));
    try std.testing.expectError(error.UnexpectedDiagnosticBoot, result.ordinaryReady(fixtures.VALID));
    try std.testing.expectError(error.UnexpectedDiagnosticBoot, result.ordinaryReady(fixtures.FIRMWARE_VALID));
    try std.testing.expectError(error.NormalBootFailed, result.ordinaryReady(fixtures.PANIC));
    try std.testing.expectError(error.NormalBootFailed, result.ordinaryReady(fixtures.ORDINARY_PULSE_FAILED));
}

test "ordinary boot proves the correct Pulse disposition in its own serial epoch" {
    const started = fixtures.ORDINARY_PULSE ++ fixtures.LF;
    const weaver = fixtures.ORDINARY_WEAVER ++ fixtures.CRLF;
    const skipped = fixtures.ORDINARY_PULSE_SKIPPED ++ fixtures.CRLF;
    const ready = fixtures.MISSING;
    try result.verifyOrdinaryPulse(started ++ weaver ++ ready, true);
    try result.verifyOrdinaryPulse(skipped ++ ready, false);
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(ready, true));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(started ++ ready, true));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(skipped ++ ready, true));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(skipped ++ weaver ++ ready, false));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(started ++ weaver ++ ready, false));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(ready ++ started ++ weaver, true));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(weaver ++ started ++ ready, true));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(started ++ started ++ weaver ++ ready, true));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(started ++ weaver ++ weaver ++ ready, true));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(started ++ skipped ++ weaver ++ ready, true));
    try std.testing.expectError(error.InvalidOrdinaryPulseEvidence, result.verifyOrdinaryPulse(fixtures.AHCI_PREFIX ++ started ++ weaver ++ ready, true));
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

test "a fresh diagnostic boot restores only preceding verified phase results" {
    try phase.liveHistory();
}

test "rollback progress is credited only when the measured schedule is verified" {
    const plan = fixtures.BOOT_ROLLBACK_BEGIN ++ fixtures.ROLLBACK_PLANNED_820;
    const pending = try result.rollbackWork(plan);
    try std.testing.expectEqual(@as(u32, 820), pending.Planned);
    try std.testing.expectEqual(@as(u32, 0), pending.Verified);
    const complete = try result.rollbackWork(plan ++ fixtures.ROLLBACK_VERIFIED_820 ++ fixtures.BOOT_ROLLBACK_END);
    try std.testing.expectEqual(@as(u32, 820), complete.Verified);
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.rollbackWork(plan ++ fixtures.ROLLBACK_VERIFIED_819 ++ fixtures.BOOT_ROLLBACK_END));
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.rollbackWork(fixtures.ROLLBACK_VERIFIED_820));
}

test "standard progress preserves only ordered completed group records" {
    const start = fixtures.BOOT_ROLLBACK_BEGIN ++ fixtures.BOOT_ROLLBACK_END ++ fixtures.BEGIN;
    try std.testing.expectEqual(@as(u16, 3), try result.standardProgress(start ++ fixtures.STANDARD_GROUP_ONE ++ fixtures.STANDARD_GROUP_TWO));
    try std.testing.expectEqual(@as(u16, 2), try result.standardProgress(start ++ fixtures.STANDARD_GROUP_ONE ++ fixtures.STANDARD_GROUP_TWO[0 .. fixtures.STANDARD_GROUP_TWO.len - 1]));
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.standardProgress(start ++ fixtures.STANDARD_GROUP_TWO));
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.standardProgress(fixtures.STANDARD_GROUP_ONE));
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.standardProgress(start ++ fixtures.STANDARD_GROUP_ONE ++ fixtures.STANDARD_GROUP_ONE));
}

test "firmware oracle accepts its own nonempty completion without kernel ready" {
    try std.testing.expectEqual(@as(?usize, 8), try result.evaluate(fixtures.FIRMWARE_VALID, .Firmware));
}

test "firmware oracle rejects standard output and an empty firmware run" {
    try std.testing.expectError(error.UnexpectedFirmwareOutcome, result.evaluate(fixtures.VALID, .Firmware));
    try std.testing.expectError(error.IncompleteGuestChecks, result.evaluate(fixtures.FIRMWARE_EMPTY, .Firmware));
    try std.testing.expectError(error.GuestCheckFailed, result.evaluate(fixtures.FIRMWARE_VALID ++ fixtures.PANIC, .Firmware));
}

test "standard requires a completed early rollback before guest checks" {
    const begin = fixtures.BOOT_ROLLBACK_BEGIN;
    const end = fixtures.BOOT_ROLLBACK_END;
    try result.verifyBootstrap(begin ++ end ++ fixtures.VALID, .Standard);
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.verifyBootstrap(fixtures.VALID, .Standard));
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.verifyBootstrap(begin ++ fixtures.VALID, .Standard));
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.verifyBootstrap(end ++ begin ++ fixtures.VALID, .Standard));
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.verifyBootstrap(begin ++ end ++ begin ++ fixtures.VALID, .Standard));
    try std.testing.expectError(error.InvalidBootstrapEvidence, result.verifyBootstrap(fixtures.VALID ++ begin ++ end, .Standard));
}

test "alternate phases reject a repeated exhaustive boot rollback" {
    for ([_]Scenario{ .PulseDeath, .Firmware, .Devices, .Collapse }) |selected| {
        try result.verifyBootstrap(fixtures.BEGIN, selected);
        try std.testing.expectError(error.UnexpectedBootstrapSweep, result.verifyBootstrap(fixtures.BOOT_ROLLBACK_BEGIN ++ fixtures.BEGIN, selected));
    }
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
    try std.testing.expectError(error.InvalidGuestCheckCount, result.evaluate(fixtures.BAD_COUNT, .Standard));
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
