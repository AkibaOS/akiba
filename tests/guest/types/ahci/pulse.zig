//! Managed Pulse Exchange Context

pub const Context = struct {
    PulseID: u64,
    Outcome: ?(anyerror!bool) = null,
};
