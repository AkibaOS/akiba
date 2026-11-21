//! One Initial Pulse Weaver Handoff

const memory = @import("shared").launch.constants.service.memory;

pub const State = struct {
    PulseID: u64,
    Image: ?[]u8,
    WeaverID: ?u64 = null,
    Confirmed: bool = false,
    HeapEnd: u64 = memory.BASE,
};
