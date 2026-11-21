//! Demand Mapped Scratch Arena Ownership

const layout = @import("shared").launch.constants.service.memory;

pub const State = struct {
    Used: usize = 0,
    Mapped: usize = 0,
    Base: u64 = layout.BASE,
    Grow: *const fn () ?u64,
};
