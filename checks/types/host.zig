//! Host Guest Check State

const builtin = @import("builtin");
const std = @import("std");

pub const Paths = struct {
    Repo: []const u8,
    Run: []const u8,
    Image: []const u8,
    Serial: []const u8,
    Variables: []const u8,
    FirmwareCode: []const u8,
    FirmwareTemplate: []const u8,
    Qemu: []const u8,
};

pub const Connection = struct {
    Stream: std.net.Stream,
    Sequence: u64 = 0,
};

pub const Stage = enum {
    Prepare,
    Spawn,
    Connect,
    Verify,
    Checks,
    Cleanup,
    Complete,
};

pub const Report = struct {
    Status: []const u8,
    Stage: Stage,
    CleanupError: ?[]const u8,
    Platform: []const u8,
    Passed: usize,
    Started: bool,
    OriginalProcessReaped: bool,
    CleanupVerified: bool,
    Image: []const u8,
    ImageSHA256: []const u8,
    Serial: []const u8,
    Error: ?[]const u8,
};

pub const Process = struct {
    Child: std.process.Child,
    Job: if (builtin.os.tag == .windows) ?std.os.windows.HANDLE else void = if (builtin.os.tag == .windows) null else {},
    Spawned: bool = false,
    Contained: bool = false,
    HandlersInstalled: bool = false,
    Reaped: bool = false,
    Finished: bool = false,
    Term: ?std.process.Child.Term = null,
};
