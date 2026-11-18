//! Loader Owned Table Tracking Page

const limits = @import("hikari").paging.constants.ledger;

pub const Ledger = struct {
    Next: ?*Ledger = null,
    Count: usize = 0,
    Frames: [limits.CAPACITY]u64 = undefined,
};
