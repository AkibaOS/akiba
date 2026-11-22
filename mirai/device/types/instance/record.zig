//! Kernel Device Instance And Assignment Records

const inventory = @import("shared").device.types.instance;

pub const Instance = inventory.Instance;
pub const Kind = inventory.Kind;

pub const Assignment = struct {
    Owner: u64,
    Handle: u64,
    Committed: bool = false,
};

pub const Record = struct {
    Device: Instance,
    Assignment: ?Assignment = null,
    Available: bool = true,
};
