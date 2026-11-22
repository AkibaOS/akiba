//! Managed Pulse Exchange Context

pub const Context = struct {
    PulseID: u64,
    WeaverID: u64,
    DiskID: u64,
    KeyboardID: u64,
    DisplayID: u64,
    Startup: bool,
    Outcome: ?(anyerror!bool) = null,
};
