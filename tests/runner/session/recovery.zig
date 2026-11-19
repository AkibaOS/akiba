//! Failed Phase Isolation Before A Cold Restore

const std = @import("std");

const protocol = @import("tests").runner.transport.protocol;
const strings = @import("tests").runner.strings.runner;
const Connection = @import("tests").runner.types.host.Connection;
const Stage = @import("tests").runner.types.host.Stage;

pub fn local(stage: Stage, reason: anyerror) bool {
    return switch (stage) {
        .Select => reason == error.GuestCheckFailed or reason == error.GuestPhaseTimeout,
        .Checks => switch (reason) {
            error.GuestCheckFailed,
            error.GuestCheckTimeout,
            error.UnexpectedFatalOutcome,
            error.UnexpectedFirmwareOutcome,
            error.MissingGuestChecks,
            error.IncompleteGuestChecks,
            error.InvalidGuestCheckCount,
            error.InvalidBootstrapEvidence,
            error.InvalidDiagnosticDisplay,
            error.UnexpectedBootstrapSweep,
            error.UnexpectedKeyboardInput,
            error.MissingInjectedInput,
            error.GuestOutcomeChanged,
            => true,
            else => false,
        },
        else => false,
    };
}

pub fn quiesce(allocator: std.mem.Allocator, connection: *Connection) !void {
    const reply = try protocol.command(allocator, connection, strings.QUERY_STATUS, null);
    defer reply.deinit();
    const state = protocol.returned(reply);
    if (protocol.equal(state, strings.STATUS, strings.PAUSED) and protocol.boolean(state, strings.RUNNING, false)) return;
    if (!protocol.equal(state, strings.STATUS, strings.RUNNING) or !protocol.boolean(state, strings.RUNNING, true)) return error.UnexpectedGuestState;
    try protocol.action(allocator, connection, strings.STOP, null);
    try protocol.verifyStatus(allocator, connection, strings.PAUSED);
}
