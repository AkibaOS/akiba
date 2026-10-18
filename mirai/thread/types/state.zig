//! Cooperative Thread States

pub const State = enum {
    Ready,
    Running,
    Blocked,
    Stopped,
};
