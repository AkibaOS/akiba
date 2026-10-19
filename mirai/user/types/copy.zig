//! Validated User Copy Segments

const limits = @import("mirai").user.constants.limits;

pub const Segment = struct {
    Alias: u64,
    Length: usize,
};

pub const Plan = struct {
    Segments: [limits.MAX_COPY_SEGMENTS]Segment = undefined,
    Count: usize = 0,
};
