//! Confirmed EFI Page Allocation

const base = @import("hikari").efi.types.base;

pub const Allocation = struct {
    Physical: base.PhysicalAddress,
    Pages: usize,
};

pub const Claim = struct {
    Backing: ?Allocation = null,
    Untrusted: bool = false,
};

pub const Acquisition = enum {
    Acquired,
    Unavailable,
    Invalid,
    Untrusted,
};
