//! Boot AHCI Authority Bound To An Exact Driver Kata

const Handoff = @import("mirai").bootstrap.types.storage.handoff.Handoff;

pub const Grant = struct {
    OwnerID: u64,
    Disk: Handoff,
    Verified: bool = false,
    Confirmed: bool = false,
    AfsID: ?u64 = null,
};
