//! Versioned Loader Table Ownership Handoff

const sizes = @import("common").constants.memory.sizes;
const limits = @import("shared").boot.constants.retirement;

pub const Inventory = extern struct {
    LedgerPhysical: u64 = 0,
    ChildFrames: u64 = 0,
    MapPages: u64 = 0,
};

pub const Ledger = extern struct {
    NextPhysical: u64 = 0,
    Count: u64 = 0,
    MapPhysical: u64 = 0,
    MapPages: u64 = 0,
    Frames: [limits.LEDGER_CAPACITY]u64 = undefined,
};

comptime {
    if (@sizeOf(Ledger) != sizes.PAGE_SIZE) unreachable;
}
