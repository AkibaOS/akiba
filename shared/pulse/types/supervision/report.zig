//! Private Pulse Service Snapshot

pub const Phase = enum(u64) { Starting, Running, Degraded, Stopping, Stopped };

pub const Snapshot = extern struct {
    Phase: Phase,
    Count: u64,
    ID: u64 = 0,
    Stage: u64 = 0,
    Starts: u64 = 0,
    Failures: u64 = 0,
    StartedAt: u64 = 0,
    StoppedAt: u64 = 0,
    WeaverID: u64,
    AfsID: u64,
    DiskID: u64,
};
