//! Host Guest Check State

const builtin = @import("builtin");
const std = @import("std");

const ActionFrame = @import("tests").phase.types.action.Frame;
const Scenario = @import("tests").types.scenario.Scenario;

pub const Paths = struct {
    Run: []const u8,
    Image: []const u8,
    FirmwareImage: []const u8,
    MenuImage: []const u8,
    OrdinaryImage: []const u8,
    Serial: []const u8,
    Variables: []const u8,
    State: []const u8,
    FirmwareCode: []const u8,
    FirmwareTemplate: []const u8,
    Qemu: []const u8,
    QemuImage: []const u8,
};

pub const Media = enum { Diagnostic, Firmware, Menu, Ordinary };

pub const Connection = struct {
    Stream: std.net.Stream,
    Sequence: u64 = 0,
};

pub const Stage = enum {
    Prepare,
    Spawn,
    Connect,
    Verify,
    Checkpoint,
    Restore,
    Select,
    Checks,
    Recovery,
    Menu,
    Ordinary,
    Complete,
};

pub const Endpoints = struct { Qmp: u16, Phase: u16, Menu: u16 };

pub const Deadline = struct {
    Timer: *std.time.Timer,
    Limit: u64,
};

pub const Epoch = struct {
    File: *const std.fs.File,
    Start: u64,
};

pub const CancelChannel = struct {
    Stream: std.net.Stream,
    Epoch: u64,
    Frame: ActionFrame = undefined,
    Received: usize = 0,
};

pub const PhaseResult = union(enum) { Passed: usize, Cancelled: usize };

pub const Fingerprint = struct {
    Size: u64,
    Modified: i128,
    Digest: [32]u8,
};

pub const Session = struct {
    Process: Process,
    Control: ?Connection = null,
    Owned: bool = false,
    OperatorExit: bool = false,
    Cancelled: bool = false,
    CleanupVerified: bool = true,
    Stage: Stage = .Prepare,
    Selected: ?Scenario = null,
    SerialStart: u64 = 0,
    Passed: usize = 0,
    StandardCompleted: u16 = 0,
    FailedMask: u8 = 0,
    InterruptedMask: u8 = 0,
};

pub const Process = struct {
    Child: std.process.Child,
    Job: if (builtin.os.tag == .windows) ?std.os.windows.HANDLE else void = if (builtin.os.tag == .windows) null else {},
    Spawned: bool = false,
    Contained: bool = false,
    Reaped: bool = false,
    Finished: bool = false,
    Term: ?std.process.Child.Term = null,
};
