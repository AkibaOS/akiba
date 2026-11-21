//! Initial Pulse Bootstrap Request Operations

pub const Operation = enum(u64) { Start, Confirm, Grow, StartupReady, StartupFailed };
