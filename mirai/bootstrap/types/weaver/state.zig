//! One Initial Pulse Weaver Handoff

pub const State = struct {
    PulseID: u64,
    Image: ?[]u8,
    WeaverID: ?u64 = null,
    Confirmed: bool = false,
};
