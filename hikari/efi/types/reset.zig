//! Hikari EFI Reset Types

pub const ResetType = enum(u32) {
    Cold = 0,
    Warm = 1,
    Shutdown = 2,
    PlatformSpecific = 3,
};
