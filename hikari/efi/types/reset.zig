//! Hikari EFI Reset Types

pub const ResetType = enum(u32) {
    cold = 0,
    warm = 1,
    shutdown = 2,
    platform_specific = 3,
};
