//! Manual Guest Checks In One Owned QEMU Session

const std = @import("std");

const checkpoint = @import("tests").runner.checkpoint;
const graph = @import("tests").runner.graph;
const image = @import("tests").runner.image;
const input = @import("tests").runner.input;
const keyboard = @import("tests").types.input;
const limits = @import("tests").constants.runner;
const paths = @import("tests").runner.paths;
const phase = @import("tests").runner.phase;
const process = @import("tests").runner.process;
const protocol = @import("tests").runner.protocol;
const result = @import("tests").runner.result;
const scenario = @import("tests").strings.scenario;
const screen = @import("tests").screen;
const serial = @import("tests").runner.serial;
const strings = @import("tests").strings.runner;
const terminal = @import("tests").runner.terminal;
const types = @import("tests").types.host;

const Allocator = std.mem.Allocator;
const Scenario = @import("tests").types.scenario.Scenario;
const PAGE = std.heap.page_allocator;

pub fn run() !void {
    terminal.begin();
    process.installCancellation() catch |failure| {
        terminal.fail(null, .Prepare, failure, null);
        return failure;
    };
    defer process.restoreCancellation();
    var arena = std.heap.ArenaAllocator.init(PAGE);
    defer arena.deinit();
    const allocator = arena.allocator();
    const inputs = paths.prepare(allocator) catch |failure| {
        terminal.fail(null, .Prepare, failure, null);
        return failure;
    };
    var session: types.Session = .{ .Process = process.init(allocator, &.{}) };
    const bases = [_][]const u8{ inputs.Image, inputs.FirmwareImage, inputs.FirmwareCode, inputs.FirmwareTemplate };
    var fingerprints: [bases.len]types.Fingerprint = undefined;
    var known: usize = 0;
    const outcome = work: {
        for (bases, &fingerprints) |path, *fingerprint| {
            fingerprint.* = image.fingerprint(path) catch |failure| break :work failure;
            known += 1;
        }
        break :work execute(allocator, &inputs, &session);
    };
    var failure: ?anyerror = if (outcome) |_| null else |reason| reason;
    const cleanup = close(&session, failure == null);
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
    terminal.total(session.Passed);
}

fn execute(allocator: Allocator, inputs: *const types.Paths, session: *types.Session) !void {
    try image.prepare(allocator, inputs, &session.CleanupVerified);
    const name = try std.fmt.allocPrint(allocator, strings.NAME_FORMAT, .{std.fs.path.basename(inputs.Run)});
    const endpoints = try reserveEndpoints();
    session.Process = process.init(allocator, try arguments(allocator, inputs, name, endpoints));
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
    try graph.verifyAttached(PAGE, connection, inputs, false);
    try graph.verifyStateStore(PAGE, connection, inputs);
    try protocol.verifySerial(PAGE, connection, inputs.Serial);
    try protocol.verifyPhasePort(PAGE, connection, endpoints.Phase);
    const log = try std.fs.cwd().openFile(inputs.Serial, .{});
    defer log.close();
    if (try log.getEndPos() != 0) return error.UnexpectedSerialHistory;
    session.Stage = .Checkpoint;
    try checkpoint.run(PAGE, &session.Process, connection, strings.SNAPSHOT_SAVE);
    try protocol.verifyStatus(PAGE, connection, strings.PRELAUNCH);

    const seed = std.crypto.random.uintLessThan(u64, std.math.maxInt(u64) - std.enums.values(Scenario).len);
    for (std.enums.values(Scenario), 1..) |selected, index| {
        session.Selected = selected;
        session.SerialStart = try log.getEndPos();
        const firmware = selected == .Firmware;
        if (index != 1) {
            session.Stage = .Restore;
            try checkpoint.run(PAGE, &session.Process, connection, strings.SNAPSHOT_LOAD);
            try protocol.verifyStatus(PAGE, connection, strings.PAUSED);
            if (try log.getEndPos() != session.SerialStart) return error.UnexpectedSerialHistory;
            try graph.select(PAGE, connection, firmware);
            try graph.verifyAttached(PAGE, connection, inputs, firmware);
        }
        const evidence: types.Epoch = .{ .File = &log, .Start = session.SerialStart };
        var timer = try std.time.Timer.start();
        session.Stage = .Select;
        if (firmware) {
            try protocol.action(PAGE, connection, strings.CONTINUE, null);
        } else {
            try protocol.verifyPhasePort(PAGE, connection, endpoints.Phase);
            const stream = try phase.open(endpoints.Phase, &session.Process, &timer);
            defer stream.close();
            try protocol.action(PAGE, connection, strings.CONTINUE, null);
            try phase.select(stream, &session.Process, &timer, evidence, .{ .Epoch = seed + index, .Scenario = selected });
        }
        session.Stage = .Checks;
        session.Passed += try completed(session, evidence, selected, &timer);
    }
    session.Stage = .Complete;
    session.Selected = null;
}

fn completed(session: *types.Session, evidence: types.Epoch, selected: Scenario, timer: *std.time.Timer) !usize {
    const connection = &session.Control.?;
    const keys = if (selected == .Devices) input.choose() else undefined;
    var challenge: keyboard.Challenge = .{ .Keys = &keys };
    while (timer.read() < limits.CHECK_NS) {
        if (process.cancelled()) return error.Cancelled;
        if (try process.exited(&session.Process)) return error.GuestExited;
        try protocol.verifyStatus(PAGE, connection, strings.RUNNING);
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
                try protocol.action(PAGE, connection, strings.STOP, null);
                try protocol.verifyStatus(PAGE, connection, strings.PAUSED);
                const frozen = try serial.read(PAGE, evidence);
                defer PAGE.free(frozen);
                if (try result.evaluate(frozen, selected) != count) return error.GuestOutcomeChanged;
                try result.verifyBootstrap(frozen, selected);
                if (selected == .Devices and try input.observe(&challenge, frozen) != .Complete) return error.MissingInjectedInput;
                if (timer.read() >= limits.CHECK_NS) return error.GuestCheckTimeout;
                terminal.passed(selected, count, frozen);
                return count;
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

fn arguments(allocator: Allocator, inputs: *const types.Paths, name: []const u8, endpoints: types.Endpoints) ![]const []const u8 {
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
        scenario.FLAG,
        scenario.PHASE_ARGUMENT,
    });
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
    return .{ .Qmp = monitor.listen_address.getPort(), .Phase = control.listen_address.getPort() };
}

fn buildDateArgument(allocator: Allocator, path: []const u8) ?[]const u8 {
    const stat = std.fs.cwd().statFile(path) catch return null;
    var buffer: [screen.constants.frame.DATE_BYTES]u8 = undefined;
    const date = screen.date.format(&buffer, stat.mtime) orelse return null;
    return std.fmt.allocPrint(allocator, scenario.BUILD_DATE_ARGUMENT, .{date}) catch null;
}

fn close(session: *types.Session, require_quit_reply: bool) !void {
    var quit_error: ?anyerror = null;
    if (session.Control) |*connection| {
        defer connection.Stream.close();
        if (session.Owned) protocol.quit(PAGE, connection) catch |failure| {
            quit_error = failure;
        };
    }
    process.close(&session.Process) catch |failure| {
        session.CleanupVerified = session.Process.Reaped and (failure == error.GuestForcedShutdown or failure == error.GuestExitFailed);
        return failure;
    };
    if (require_quit_reply) if (quit_error) |failure| return failure;
}

fn failedEvidence(allocator: Allocator, inputs: *const types.Paths, offset: u64) ?[]u8 {
    const log = std.fs.cwd().openFile(inputs.Serial, .{}) catch return null;
    defer log.close();
    return serial.read(allocator, .{ .File = &log, .Start = offset }) catch null;
}
