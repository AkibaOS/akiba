//! Manual Guest Checks In One Owned QEMU Session

const std = @import("std");

const checkpoint = @import("tests").runner.machine.checkpoint;
const datefields = @import("tests").phase.constants.date.format;
const datecode = @import("tests").phase.date;
const graph = @import("tests").runner.machine.graph;
const image = @import("tests").runner.machine.image;
const input = @import("tests").runner.session.input;
const keyboard = @import("tests").runner.types.input;
const limits = @import("tests").runner.constants.limits;
const live = @import("tests").phase.constants.live.frame;
const markers = @import("tests").phase.strings.serial;
const menubits = @import("tests").phase.menu;
const pathnames = @import("tests").runner.strings.paths;
const paths = @import("tests").runner.machine.paths;
const phase = @import("tests").runner.transport.phase;
const process = @import("tests").runner.process.lifetime;
const protocol = @import("tests").runner.transport.protocol;
const recovery = @import("tests").runner.session.recovery;
const result = @import("tests").runner.report.result;
const scenario = @import("tests").phase.strings.scenario;
const serial = @import("tests").runner.transport.serial;
const strings = @import("tests").runner.strings.runner;
const terminal = @import("tests").runner.report.terminal;
const types = @import("tests").runner.types.host;
const work = @import("tests").runner.work;

const Allocator = std.mem.Allocator;
const BootSelection = @import("tests").phase.types.boot.frame.Selection;
const Scenario = @import("tests").phase.types.scenario.Scenario;
const PAGE = std.heap.page_allocator;

pub fn run(unattended: bool, ahci: bool) !void {
    terminal.begin();
    process.installCancellation() catch |failure| {
        terminal.fail(null, .Prepare, failure, null);
        return failure;
    };
    defer process.restoreCancellation();
    var arena = std.heap.ArenaAllocator.init(PAGE);
    defer arena.deinit();
    const allocator = arena.allocator();
    var inputs = paths.prepare(allocator) catch |failure| {
        terminal.fail(null, .Prepare, failure, null);
        return failure;
    };
    var session: types.Session = .{ .Process = process.init(allocator, &.{}), .Work = .{ .Planned = work.reference() }, .Ahci = ahci };
    const bases = [_][]const u8{ inputs.Image, inputs.FirmwareCode, inputs.FirmwareTemplate };
    var fingerprints: [bases.len]types.Fingerprint = undefined;
    var known: usize = 0;
    const outcome = work: {
        for (bases, &fingerprints) |path, *fingerprint| {
            fingerprint.* = image.fingerprint(path) catch |failure| break :work failure;
            known += 1;
        }
        if (ahci) inputs.BootOverlay = std.fs.path.join(allocator, &.{ inputs.Run, pathnames.BOOT_OVERLAY_FILE }) catch |failure| break :work failure;
        break :work execute(allocator, &inputs, &session, unattended);
    };
    var failure: ?anyerror = if (outcome) |_| null else |reason| reason;
    const cleanup = close(&session, failure == null);
    if (session.OperatorExit and failure == null) {
        verifyOrdinaryExit(&inputs, session.SerialStart, session.Ahci) catch |reason| {
            failure = reason;
            session.Stage = .Ordinary;
        };
    }
    const diagnostic = if (failure != null) failedEvidence(allocator, &inputs, session.SerialStart) else null;
    if (session.Process.Spawned and !session.Process.Reaped) session.CleanupVerified = false;
    var cleanup_error: ?anyerror = if (cleanup) |_| null else |reason| reason;
    if (session.CleanupVerified) std.fs.cwd().deleteTree(inputs.Run) catch |reason| {
        session.CleanupVerified = false;
        cleanup_error = reason;
    };
    for (bases[0..known], fingerprints[0..known]) |path, before| {
        const after = image.fingerprint(path) catch null;
        if (after == null or !std.meta.eql(before, after.?)) {
            std.log.err(strings.INPUT_CHANGED, .{path});
            if (failure == null) failure = error.GuestImageChanged;
        }
    }
    if (failure) |reason| terminal.fail(session.Selected, session.Stage, reason, diagnostic);
    terminal.cleanup(session.Process.Spawned, cleanup_error, session.CleanupVerified);
    if (cleanup_error) |reason| return reason;
    if (failure) |reason| return reason;
    if (session.Cancelled) return error.GuestChecksCancelled;
    if (session.FailedMask != 0) {
        if (unattended) terminal.failedTotal(session.Passed, @popCount(session.FailedMask));
        return error.GuestSuiteFailed;
    }
    if (unattended) terminal.total(session.Passed);
}

fn execute(allocator: Allocator, inputs: *const types.Paths, session: *types.Session, unattended: bool) !void {
    try image.prepare(allocator, inputs, &session.CleanupVerified);
    const name = try std.fmt.allocPrint(allocator, strings.NAME_FORMAT, .{std.fs.path.basename(inputs.Run)});
    const endpoints = try reserveEndpoints();
    session.Process = process.init(allocator, try arguments(allocator, inputs, name, endpoints, unattended));
    session.Stage = .Spawn;
    try process.spawn(&session.Process, inputs, allocator);
    session.Stage = .Connect;
    session.Control = try connect(&session.Process, endpoints.Qmp);
    const connection = &session.Control.?;
    session.Stage = .Verify;
    try protocol.verifyName(PAGE, connection, name);
    session.Owned = true;
    try protocol.verifyStatus(PAGE, connection, strings.PRELAUNCH);
    try protocol.verifyWindow(PAGE, connection);
    try graph.verifyAttached(PAGE, connection, inputs);
    try graph.verifyStateStore(PAGE, connection, inputs);
    try protocol.verifySerial(PAGE, connection, inputs.Serial);
    try protocol.verifyControlPort(PAGE, connection, strings.PHASE_LABEL, endpoints.Phase);
    try protocol.verifyControlPort(PAGE, connection, strings.MENU_LABEL, endpoints.Menu);
    try protocol.verifyControlPort(PAGE, connection, strings.SELECTOR_LABEL, endpoints.Selector);
    const log = try std.fs.cwd().openFile(inputs.Serial, .{});
    defer log.close();
    if (try log.getEndPos() != 0) return error.UnexpectedSerialHistory;
    session.Stage = .Checkpoint;
    try checkpoint.run(PAGE, &session.Process, connection, strings.SNAPSHOT_SAVE, session.Ahci);
    try protocol.verifyStatus(PAGE, connection, strings.PRELAUNCH);

    var build_date: [datefields.DATE_BYTES]u8 = undefined;
    _ = buildDate(&build_date, inputs.Image) orelse return error.InvalidMenuBuildDate;
    var selector_timer = try std.time.Timer.start();
    session.Stage = .Connect;
    const selector = try phase.open(endpoints.Selector, &session.Process, &selector_timer);
    defer selector.close();

    const menu_slot = std.enums.values(Scenario).len + 1;
    const seed = std.crypto.random.uintLessThan(u64, std.math.maxInt(u64) - menu_slot - 1);
    for (std.enums.values(Scenario), 1..) |selected, index| {
        session.Selected = selected;
        session.SerialStart = try log.getEndPos();
        if (index != 1) {
            session.Stage = .Restore;
            try restore(inputs, session, &log);
        }
        const evidence: types.Epoch = .{ .File = &log, .Start = session.SerialStart };
        const outcome = runPhase(session, evidence, selected, selector, endpoints, seed + index, build_date, !unattended) catch |failure| {
            if (!recovery.local(session.Stage, failure)) return failure;
            try failPhase(session, evidence, selected, failure);
            continue;
        };
        switch (outcome) {
            .Passed => |count| {
                session.Passed += count;
                if (selected == .Standard) session.StandardCompleted = live.STANDARD_UNITS;
            },
            .Cancelled => |count| {
                session.Passed += count;
                session.Cancelled = true;
                break;
            },
        }
    }
    session.Selected = null;
    if (session.Cancelled) {
        std.debug.print(strings.CANCELLED_RESULT, .{session.Passed});
        try bootOrdinary(inputs, session, &log, selector, seed + menu_slot + 1);
    } else if (!unattended) {
        if (session.FailedMask == 0) terminal.total(session.Passed) else terminal.failedTotal(session.Passed, @popCount(session.FailedMask));
        try postSuite(inputs, session, &log, selector, endpoints.Menu, seed + menu_slot);
    }
    session.Stage = .Complete;
}

fn runPhase(session: *types.Session, evidence: types.Epoch, selected: Scenario, selector: std.net.Stream, endpoints: types.Endpoints, epoch: u64, build_date: [datefields.DATE_BYTES]u8, interactive: bool) !types.PhaseResult {
    const connection = &session.Control.?;
    var timer = try std.time.Timer.start();
    session.Stage = .Select;
    const firmware = selected == .Firmware;
    const port = if (firmware) endpoints.Menu else endpoints.Phase;
    try protocol.verifyControlPort(PAGE, connection, if (firmware) strings.MENU_LABEL else strings.PHASE_LABEL, port);
    const stream = try phase.open(port, &session.Process, &timer);
    defer stream.close();
    try beginRole(session, selector, evidence, &timer, .{ .Epoch = epoch, .Role = if (firmware) .Firmware else .Diagnostic });
    const verified_checks = std.math.cast(u32, session.Passed) orelse return error.InvalidMenuCount;
    try phase.start(stream, &session.Process, &timer, evidence, .{
        .Ticket = .{ .Epoch = epoch, .Scenario = selected },
        .Date = build_date,
        .FailedMask = session.FailedMask,
        .InterruptedMask = session.InterruptedMask,
        .StandardCompleted = session.StandardCompleted,
        .VerifiedChecks = verified_checks,
        .Work = session.Work,
    });
    var channel: types.CancelChannel = .{ .Stream = stream, .Epoch = epoch };
    session.Stage = .Checks;
    return completed(session, evidence, selected, &timer, if (interactive and (selected == .Standard or firmware)) &channel else null);
}

fn beginRole(session: *types.Session, selector: std.net.Stream, evidence: types.Epoch, timer: *std.time.Timer, selection: BootSelection) !void {
    try protocol.action(PAGE, &session.Control.?, strings.CONTINUE, null);
    try phase.selectBoot(selector, &session.Process, timer, evidence, selection);
}

fn failPhase(session: *types.Session, evidence: types.Epoch, selected: Scenario, failure: anyerror) !void {
    const failed_at = session.Stage;
    session.Stage = .Recovery;
    const quiesced = prepareRecovery(session);
    const bytes = serial.read(PAGE, evidence) catch null;
    defer if (bytes) |captured| PAGE.free(captured);
    terminal.fail(selected, failed_at, failure, bytes);
    const bit = menubits.phaseBit(selected);
    session.FailedMask |= bit;
    const completed_failure = failed_at == .Checks and failure == error.GuestCheckFailed and
        std.mem.indexOf(u8, bytes orelse &.{}, markers.FAIL) != null;
    if (!completed_failure) session.InterruptedMask |= bit;
    try quiesced;
    if (failed_at != .Checks) return;
    const captured = bytes orelse return;
    work.retain(&session.Work, selected, result.partialChecks(captured, selected));
    if (selected == .Standard) {
        if (result.rollbackWork(captured)) |rollback| {
            session.Work.addPlan(rollback.Planned);
            session.Work.credit(rollback.Verified);
        } else |_| {}
        if (result.standardProgress(captured)) |finished| {
            session.StandardCompleted = @min(live.STANDARD_UNITS, finished + @intFromBool(completed_failure));
        } else |_| {}
    }
}

fn prepareRecovery(session: *types.Session) !void {
    if (process.cancelled()) return error.Cancelled;
    if (!session.Owned or try process.exited(&session.Process)) return error.GuestExited;
    try recovery.quiesce(PAGE, &session.Control.?);
}

fn postSuite(inputs: *const types.Paths, session: *types.Session, log: *const std.fs.File, selector: std.net.Stream, port: u16, epoch: u64) !void {
    const connection = &session.Control.?;
    session.Stage = .Menu;
    try restore(inputs, session, log);
    var timer = try std.time.Timer.start();
    const action = choose: {
        try protocol.verifyControlPort(PAGE, connection, strings.MENU_LABEL, port);
        const stream = try phase.open(port, &session.Process, &timer);
        defer stream.close();
        const evidence: types.Epoch = .{ .File = log, .Start = session.SerialStart };
        var date: [datefields.DATE_BYTES]u8 = undefined;
        _ = buildDate(&date, inputs.Image) orelse return error.InvalidMenuBuildDate;
        const passed = std.math.cast(u32, session.Passed) orelse return error.InvalidMenuCount;
        try beginRole(session, selector, evidence, &timer, .{ .Epoch = epoch, .Role = .Menu });
        break :choose try phase.choose(stream, &session.Process, &timer, evidence, .{
            .Epoch = epoch,
            .Passed = passed,
            .Date = date,
            .FailedMask = session.FailedMask,
            .InterruptedMask = session.InterruptedMask,
            .StandardCompleted = session.StandardCompleted,
            .Work = session.Work,
        });
    };
    try protocol.verifyStatus(PAGE, connection, strings.RUNNING);
    std.debug.print(strings.MENU_ACTION, .{@tagName(action)});
    switch (action) {
        .Shutdown => return,
        .Boot, .Timeout => {
            try stopRunning(connection);
            try bootOrdinary(inputs, session, log, selector, epoch + 1);
        },
        .Cancel => return error.InvalidMenuAction,
    }
}

fn restore(inputs: *const types.Paths, session: *types.Session, log: *const std.fs.File) !void {
    const connection = &session.Control.?;
    session.SerialStart = try log.getEndPos();
    try checkpoint.run(PAGE, &session.Process, connection, strings.SNAPSHOT_LOAD, session.Ahci);
    try protocol.verifyStatus(PAGE, connection, strings.PAUSED);
    if (try log.getEndPos() != session.SerialStart) return error.UnexpectedSerialHistory;
    try graph.verifyAttached(PAGE, connection, inputs);
}

fn stopRunning(connection: *types.Connection) !void {
    try protocol.action(PAGE, connection, strings.STOP, null);
    try protocol.verifyStatus(PAGE, connection, strings.PAUSED);
}

fn bootOrdinary(inputs: *const types.Paths, session: *types.Session, log: *const std.fs.File, selector: std.net.Stream, epoch: u64) !void {
    const connection = &session.Control.?;
    session.Stage = .Ordinary;
    try restore(inputs, session, log);
    const evidence: types.Epoch = .{ .File = log, .Start = session.SerialStart };
    var timer = try std.time.Timer.start();
    try beginRole(session, selector, evidence, &timer, .{ .Epoch = epoch, .Role = .Ordinary });
    while (timer.read() < limits.START_NS) {
        if (process.cancelled()) return error.Cancelled;
        if (try process.exited(&session.Process)) return error.GuestExited;
        try protocol.verifyStatus(PAGE, connection, strings.RUNNING);
        const bytes = try serial.read(PAGE, evidence);
        defer PAGE.free(bytes);
        if (try result.ordinaryReady(bytes)) {
            try result.verifyOrdinaryPulse(bytes, session.Ahci);
            std.debug.print(strings.ORDINARY_READY, .{});
            try protocol.superviseOrdinary(PAGE, connection, evidence);
            session.OperatorExit = true;
            return;
        }
        std.Thread.sleep(limits.POLL_NS);
    }
    return error.OrdinaryBootTimeout;
}

fn completed(session: *types.Session, evidence: types.Epoch, selected: Scenario, timer: *std.time.Timer, cancellation: ?*types.CancelChannel) !types.PhaseResult {
    const connection = &session.Control.?;
    const keys = if (selected == .Devices) input.choose() else undefined;
    var challenge: keyboard.Challenge = .{ .Keys = &keys };
    while (timer.read() < limits.CHECK_NS) {
        if (process.cancelled()) return error.Cancelled;
        if (try process.exited(&session.Process)) return error.GuestExited;
        try protocol.verifyStatus(PAGE, connection, strings.RUNNING);
        if (cancellation) |channel| {
            if (try phase.cancellation(channel)) {
                if (try protocol.halted(PAGE, connection)) {
                    try stopRunning(connection);
                    const frozen = try serial.read(PAGE, evidence);
                    defer PAGE.free(frozen);
                    return .{ .Cancelled = try result.cancelledCount(frozen) };
                }
                std.Thread.sleep(limits.POLL_NS);
                continue;
            }
        }
        const bytes = try serial.read(PAGE, evidence);
        defer PAGE.free(bytes);
        const passed = try result.evaluate(bytes, selected);
        if (selected == .Devices) {
            const action = try input.observe(&challenge, bytes);
            if (passed != null and action != .Complete) return error.MissingInjectedInput;
            if (action == .Inject) {
                try protocol.pressKey(PAGE, connection, keys[challenge.Index].Name);
                input.sent(&challenge);
            }
        }
        if (passed) |count| {
            const expected_halt = selected == .Firmware or selected == .PulseDeath or selected == .Collapse;
            if (!expected_halt or try protocol.halted(PAGE, connection)) {
                if (cancellation) |channel| if (channel.Received != 0) return error.InvalidCancellationAction;
                try stopRunning(connection);
                const frozen = try serial.read(PAGE, evidence);
                defer PAGE.free(frozen);
                if (try result.evaluate(frozen, selected) != count) return error.GuestOutcomeChanged;
                try result.verifyBootstrap(frozen, selected);
                if (selected != .Firmware) try result.verifyDisplay(frozen);
                if (selected == .Standard and try result.standardProgress(frozen) != live.STANDARD_UNITS) return error.InvalidBootstrapEvidence;
                if (selected == .Devices) {
                    if (try input.observe(&challenge, frozen) != .Complete) return error.MissingInjectedInput;
                    if (session.Ahci) try result.verifyAhci(frozen);
                }
                const assertions = std.math.cast(u32, count) orelse return error.InvalidGuestCheckCount;
                const rollback = if (selected == .Standard) try result.rollbackWork(frozen) else null;
                if (rollback) |sweep| if (sweep.Verified == 0) return error.InvalidBootstrapEvidence;
                if (timer.read() >= limits.CHECK_NS) return error.GuestCheckTimeout;
                if (rollback) |sweep| {
                    session.Work.addPlan(sweep.Planned);
                    session.Work.credit(sweep.Verified);
                }
                work.settle(&session.Work, selected, assertions);
                terminal.passed(selected, count, frozen);
                return .{ .Passed = count };
            }
        }
        std.Thread.sleep(limits.POLL_NS);
    }
    return error.GuestCheckTimeout;
}

fn connect(instance: *types.Process, port: u16) !types.Connection {
    var timer = try std.time.Timer.start();
    while (timer.read() < limits.START_NS) {
        if (process.cancelled()) return error.Cancelled;
        if (try process.exited(instance)) return error.GuestExited;
        return protocol.open(PAGE, port) catch |failure| switch (failure) {
            error.ConnectionRefused => {
                std.Thread.sleep(limits.POLL_NS);
                continue;
            },
            else => return failure,
        };
    }
    return error.GuestStartTimeout;
}

fn arguments(allocator: Allocator, inputs: *const types.Paths, name: []const u8, endpoints: types.Endpoints, unattended: bool) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    try list.appendSlice(allocator, &.{
        inputs.Qemu,
        strings.MACHINE_FLAG,
        strings.MACHINE,
        strings.ACCEL_FLAG,
        strings.ACCEL,
        strings.MEMORY_FLAG,
        strings.MEMORY,
        strings.NO_DEFAULTS_FLAG,
        strings.PAUSE_AT_START_FLAG,
        strings.REBOOT_FLAG,
        strings.NETWORK_FLAG,
        strings.NETWORK_NONE,
        strings.DEVICE_FLAG,
        strings.VGA,
        strings.NAME_FLAG,
        name,
        strings.QMP_FLAG,
        try std.fmt.allocPrint(allocator, strings.QMP_ARGUMENT, .{endpoints.Qmp}),
        strings.SERIAL_FLAG,
        try std.fmt.allocPrint(allocator, strings.SERIAL_ARGUMENT, .{inputs.Serial}),
        strings.CHARDEV_FLAG,
        try std.fmt.allocPrint(allocator, strings.PHASE_SOCKET, .{endpoints.Phase}),
        strings.SERIAL_FLAG,
        strings.PHASE_SERIAL,
        strings.CHARDEV_FLAG,
        try std.fmt.allocPrint(allocator, strings.MENU_SOCKET, .{endpoints.Menu}),
        strings.SERIAL_FLAG,
        strings.MENU_SERIAL,
        strings.CHARDEV_FLAG,
        try std.fmt.allocPrint(allocator, strings.SELECTOR_SOCKET, .{endpoints.Selector}),
        strings.SERIAL_FLAG,
        strings.SELECTOR_SERIAL,
        scenario.FLAG,
        scenario.PHASE_ARGUMENT,
        scenario.FLAG,
        scenario.LIVE_ARGUMENT,
    });
    if (!unattended) try list.appendSlice(allocator, &.{ scenario.FLAG, scenario.CANCEL_ARGUMENT });
    if (inputs.BootOverlay != null) try list.appendSlice(allocator, &.{ scenario.FLAG, scenario.AHCI_ARGUMENT });
    if (buildDateArgument(allocator, inputs.Image)) |date| try list.appendSlice(allocator, &.{ scenario.FLAG, date });
    try graph.arguments(allocator, &list, inputs);
    return list.items;
}

fn reserveEndpoints() !types.Endpoints {
    const address = try std.net.Address.parseIp4(strings.ADDRESS, 0);
    var monitor = try address.listen(.{});
    defer monitor.deinit();
    var control = try address.listen(.{});
    defer control.deinit();
    var menu = try address.listen(.{});
    defer menu.deinit();
    var selector = try address.listen(.{});
    defer selector.deinit();
    return .{
        .Qmp = monitor.listen_address.getPort(),
        .Phase = control.listen_address.getPort(),
        .Menu = menu.listen_address.getPort(),
        .Selector = selector.listen_address.getPort(),
    };
}

fn buildDateArgument(allocator: Allocator, path: []const u8) ?[]const u8 {
    var buffer: [datefields.DATE_BYTES]u8 = undefined;
    const date = buildDate(&buffer, path) orelse return null;
    return std.fmt.allocPrint(allocator, scenario.BUILD_DATE_ARGUMENT, .{date}) catch null;
}

fn buildDate(buffer: *[datefields.DATE_BYTES]u8, path: []const u8) ?[]const u8 {
    const stat = std.fs.cwd().statFile(path) catch return null;
    return datecode.format(buffer, stat.mtime);
}

fn close(session: *types.Session, require_quit_reply: bool) !void {
    var quit_error: ?anyerror = null;
    if (session.Control) |*connection| {
        defer connection.Stream.close();
        if (session.Owned and !session.OperatorExit) protocol.quit(PAGE, connection) catch |failure| {
            quit_error = failure;
        };
    }
    process.close(&session.Process) catch |failure| {
        session.CleanupVerified = session.Process.Reaped and (failure == error.GuestForcedShutdown or failure == error.GuestExitFailed);
        return failure;
    };
    if (require_quit_reply) if (quit_error) |failure| return failure;
}

fn verifyOrdinaryExit(inputs: *const types.Paths, offset: u64, ahci: bool) !void {
    const log = try std.fs.cwd().openFile(inputs.Serial, .{});
    defer log.close();
    const bytes = try serial.read(PAGE, .{ .File = &log, .Start = offset });
    defer PAGE.free(bytes);
    if (!try result.ordinaryReady(bytes)) return error.OrdinaryEvidenceLost;
    try result.verifyOrdinaryPulse(bytes, ahci);
}

fn failedEvidence(allocator: Allocator, inputs: *const types.Paths, offset: u64) ?[]u8 {
    const log = std.fs.cwd().openFile(inputs.Serial, .{}) catch return null;
    defer log.close();
    return serial.read(allocator, .{ .File = &log, .Start = offset }) catch null;
}
